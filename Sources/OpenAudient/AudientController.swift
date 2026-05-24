import Foundation
import Combine

/// High-frequency input peak levels (dBFS), kept separate from `AudientController`
/// so the ~20 Hz meter updates only re-render the meter views, not the whole UI.
@MainActor
public final class MeterReadings: ObservableObject {
    @Published public var inputsDB: [Float] = []
    @Published public var allDB: [Float] = []
    @Published public var outputsDB: [Float] = []
    public init() {}
}

/// Observable view-model over an `AudientDevice`, for SwiftUI.
///
/// Owns the connection lifecycle (auto-connects via `DeviceMonitor`), mirrors the
/// readable control values as `@Published` state, and applies writes optimistically
/// (UI updates immediately; the USB write runs on the device's background queue).
/// Many controls are write-only over USB, so this mirror is the UI's source of truth.
@MainActor
public final class AudientController: ObservableObject {
    public enum Connection: Equatable {
        case disconnected
        case connecting(DeviceModel)
        case connected(DeviceModel)
        case error(String)
    }

    @Published public private(set) var connection: Connection = .disconnected

    // Monitor section
    @Published public var cut = false
    @Published public var dim = false
    @Published public var mono = false
    @Published public var polarity = false
    @Published public var talkback = false
    @Published public var mainVolumeDB: Double = 0
    @Published public var mixerLevelsDB: [Double] = []
    @Published public var dawReturnLevelsDB: [Double] = []
    @Published public var mainMixSourceLevelsDB: [Double] = []
    @Published public var sendSourceLevelsDB: [Mixer.SendBus: [Double]] = [:]
    @Published public var selectedSendBus: Mixer.SendBus = .main
    @Published public var mutedMainMixSources: Set<Int> = []
    @Published public var soloedMainMixSources: Set<Int> = []
    @Published public var outputRouteSources: [UInt8?] = []

    /// Live input peak meters (separate object to avoid re-rendering the whole UI).
    public let meters = MeterReadings()

    /// How often the input meters are polled.
    public var meterInterval: Duration = .milliseconds(50)

    private var device: AudientDevice?
    private let monitor = DeviceMonitor()
    private var monitorTask: Task<Void, Never>?
    private var meterTask: Task<Void, Never>?
    private var storedMainMixSourceLevels: [Int: Double] = [:]
    private var preSoloMainMixSourceLevels: [Double]?

    public init() {}
    deinit { monitorTask?.cancel() }

    public var model: DeviceModel? {
        switch connection {
        case .connecting(let m), .connected(let m): return m
        default: return nil
        }
    }
    public var isConnected: Bool { if case .connected = connection { return true } else { return false } }

    /// Start watching for device connect/disconnect (and connect when present).
    public func start() {
        guard monitorTask == nil else { return }
        monitorTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.monitor.events() {
                switch event {
                case .connected(let model): await self.handleConnected(model)
                case .disconnected: self.handleDisconnected()
                }
            }
        }
    }

    public func stop() {
        meterTask?.cancel()
        meterTask = nil
        monitorTask?.cancel()
        monitorTask = nil
    }

    private func handleConnected(_ model: DeviceModel) async {
        connection = .connecting(model)
        do {
            device = try await AudientDevice.openFirst(model)
            connection = .connected(model)
            await refresh()
            startMeters(inputChannels: model.micInputs, diagnosticChannels: model.peakMeterChannels)
        } catch {
            device = nil
            connection = .error("\(error)")
        }
    }

    private func handleDisconnected() {
        meterTask?.cancel()
        meterTask = nil
        meters.inputsDB = []
        meters.allDB = []
        meters.outputsDB = []
        mainMixSourceLevelsDB = []
        sendSourceLevelsDB = [:]
        selectedSendBus = .main
        mutedMainMixSources = []
        soloedMainMixSources = []
        outputRouteSources = []
        storedMainMixSourceLevels = [:]
        preSoloMainMixSourceLevels = nil
        device = nil
        connection = .disconnected
    }

    private func startMeters(inputChannels: Int, diagnosticChannels: Int) {
        meterTask?.cancel()
        guard inputChannels > 0 else { return }
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let device = self.device else { return }
                if let levels = try? await device.readPeakMeters(channels: diagnosticChannels) {
                    self.meters.allDB = levels
                    self.meters.inputsDB = Array(levels.prefix(inputChannels))
                } else if let levels = try? await device.readInputMeters(channels: inputChannels) {
                    self.meters.inputsDB = levels
                }
                if let outputChannels = self.model?.totalOutputs,
                   outputChannels > 0,
                   let levels = try? await device.readOutputMeters(channels: outputChannels) {
                    self.meters.outputsDB = levels
                }
                try? await Task.sleep(for: self.meterInterval)
            }
        }
    }

    /// Re-read the readable controls from the device.
    public func refresh() async {
        guard let device else { return }
        cut = (try? await device.read(Monitor.cut)) ?? cut
        dim = (try? await device.read(Monitor.dim)) ?? dim
        mono = (try? await device.read(Monitor.mono)) ?? mono
        polarity = (try? await device.read(Monitor.polarity)) ?? polarity
        talkback = (try? await device.read(Monitor.talkback)) ?? talkback
        mainVolumeDB = (try? await device.read(Monitor.mainVolume)) ?? mainVolumeDB
        let outputs = model?.totalOutputs ?? 0
        outputRouteSources = await readOutputRouteSources(outputs: outputs)

        let inputs = model?.micInputs ?? 0
        let sourceCount = max(model?.peakMeterChannels ?? max(inputs, 1), (controllableMainMixSources.max() ?? 0) + 1)
        let sourceLevels = sendSourceLevelsDB[.main] ?? Array(repeating: -60.0, count: sourceCount)
        if sendSourceLevelsDB[.main] == nil {
            sendSourceLevelsDB[.main] = sourceLevels
        }
        mainMixSourceLevelsDB = sourceLevels
        mutedMainMixSources = mutedMainMixSources.intersection(controllableMainMixSources)

        var levels: [Double] = []
        for input in 0..<inputs {
            let source = model?.mixerSource(forPeakChannel: input)
            levels.append(source.map { sourceLevels.indices.contains($0) ? sourceLevels[$0] : -128 } ?? -128)
        }
        mixerLevelsDB = levels

        var dawLevels: [Double] = []
        for pair in 0..<Mixer.dawReturnPairs {
            let peakChannel = (model?.totalInputs ?? inputs) + pair * 2
            let source = model?.mixerSource(forPeakChannel: peakChannel)
            dawLevels.append(source.map { sourceLevels.indices.contains($0) ? sourceLevels[$0] : -128 } ?? -128)
        }
        dawReturnLevelsDB = dawLevels
    }

    // MARK: Actions (optimistic: update state now, write in the background)

    public func setCut(_ on: Bool)       { apply(Monitor.cut, on) { self.cut = on } }
    public func setDim(_ on: Bool)       { apply(Monitor.dim, on) { self.dim = on } }
    public func setMono(_ on: Bool)      { apply(Monitor.mono, on) { self.mono = on } }
    public func setPolarity(_ on: Bool)  { apply(Monitor.polarity, on) { self.polarity = on } }
    public func setTalkback(_ on: Bool)  { apply(Monitor.talkback, on) { self.talkback = on } }
    public func setMainVolume(_ db: Double) { apply(Monitor.mainVolume, db) { self.mainVolumeDB = db } }

    /// Set an input's level in the main mix (writes both L and R sends).
    public func setMixerLevel(input: Int, db: Double) {
        if input < mixerLevelsDB.count { mixerLevelsDB[input] = db }
        guard let source = model?.mixerSource(forPeakChannel: input) else { return }
        setMainMixSourceLevel(source: source, db: db)
    }

    /// Set a DAW return pair's level in the main mix (writes both L and R sends).
    public func setDAWReturnLevel(pair: Int, db: Double) {
        if pair < dawReturnLevelsDB.count { dawReturnLevelsDB[pair] = db }
        guard let model else { return }
        let peakChannel = model.totalInputs + pair * 2
        if let left = model.mixerSource(forPeakChannel: peakChannel) {
            setMainMixSourceLevel(source: left, db: db)
        }
        if let right = model.mixerSource(forPeakChannel: peakChannel + 1) {
            setMainMixSourceLevel(source: right, db: db)
        }
    }

    public func setMainMixSourceLevel(source: Int, db: Double) {
        guard isControllableMainMixSource(source) else { return }
        setMainMixSourceLevelLocally(source: source, db: db)
        if db > -60 { mutedMainMixSources.remove(source) }
        guard let device else { return }
        let send = Mixer.mainSend(source: UInt8(source))
        Task {
            _ = try? await device.write(send.left, db)
            _ = try? await device.write(send.right, db)
        }
    }

    public func setMainMixStereoPairLevel(pairStartingAt source: Int, db: Double) {
        setMainMixSourceLevel(source: source, db: db)
        if isControllableMainMixSource(source + 1) {
            setMainMixSourceLevel(source: source + 1, db: db)
        }
    }

    public func setSelectedSendBus(_ bus: Mixer.SendBus) {
        guard bus.hasSourceLevelControls else { return }
        selectedSendBus = bus
        if sendSourceLevelsDB[bus] == nil {
            let sourceCount = max(model?.peakMeterChannels ?? 1, (controllableMainMixSources.max() ?? 0) + 1)
            sendSourceLevelsDB[bus] = Array(repeating: -60.0, count: sourceCount)
        }
    }

    public func sendSourceLevel(source: Int, bus: Mixer.SendBus) -> Double {
        guard let levels = sendSourceLevelsDB[bus], levels.indices.contains(source) else { return -60 }
        return levels[source]
    }

    public func canControlSendSource(_ source: Int, bus: Mixer.SendBus) -> Bool {
        guard isControllableMainMixSource(source), isSafeMixerSource(source) else { return false }
        return sendControls(source: source, bus: bus) != nil
    }

    public func setSendSourceLevel(source: Int, bus: Mixer.SendBus, db: Double) {
        guard canControlSendSource(source, bus: bus) else { return }
        setSendSourceLevelLocally(source: source, bus: bus, db: db)
        if bus == .main, db > -60 { mutedMainMixSources.remove(source) }
        guard let device else { return }
        guard let send = sendControls(source: source, bus: bus) else { return }
        Task {
            _ = try? await device.write(send.left, db)
            _ = try? await device.write(send.right, db)
        }
    }

    public func setSendStereoPairLevel(pairStartingAt source: Int, bus: Mixer.SendBus, db: Double) {
        setSendSourceLevel(source: source, bus: bus, db: db)
        if canControlSendSource(source + 1, bus: bus) {
            setSendSourceLevel(source: source + 1, bus: bus, db: db)
        }
    }

    public func setMainMixSourceMuted(source: Int, muted: Bool) {
        guard isControllableMainMixSource(source) else { return }
        if muted {
            if !mutedMainMixSources.contains(source) {
                storedMainMixSourceLevels[source] = mainMixSourceLevel(source)
            }
            mutedMainMixSources.insert(source)
            writeMainMixSourceLevel(source: source, db: -128)
            setMainMixSourceLevelLocally(source: source, db: -128)
        } else {
            mutedMainMixSources.remove(source)
            let restored = storedMainMixSourceLevels.removeValue(forKey: source) ?? -60
            writeMainMixSourceLevel(source: source, db: restored)
            setMainMixSourceLevelLocally(source: source, db: restored)
        }
    }

    public func setMainMixSourceSoloed(source: Int, soloed: Bool) {
        guard isControllableMainMixSource(source) else { return }
        if soloed {
            if soloedMainMixSources.isEmpty {
                preSoloMainMixSourceLevels = mainMixSourceLevelsDB
            }
            soloedMainMixSources.insert(source)
        } else {
            soloedMainMixSources.remove(source)
        }
        applySoloState()
    }

    public func outputRouteSource(forPairStartingAt output: Int) -> Routing.Source? {
        guard output >= 0,
              outputRouteSources.indices.contains(output),
              outputRouteSources.indices.contains(output + 1),
              let left = outputRouteSources[output],
              let right = outputRouteSources[output + 1] else { return nil }
        return Routing.Source.matching(leftOutput: output, leftValue: left, rightValue: right)
    }

    public func setOutputRoute(pairStartingAt output: Int, source: Routing.Source) {
        guard output >= 0 else { return }
        let left = source.value(forOutput: output)
        let right = source.value(forOutput: output + 1)
        setOutputRouteSourceLocally(output: output, value: left)
        setOutputRouteSourceLocally(output: output + 1, value: right)
        guard let device else { return }
        Task {
            _ = try? await device.write(Routing.source(output: UInt8(output)), left)
            _ = try? await device.write(Routing.source(output: UInt8(output + 1)), right)
        }
    }

    private func applySoloState() {
        guard !mainMixSourceLevelsDB.isEmpty else { return }
        if soloedMainMixSources.isEmpty {
            if let levels = preSoloMainMixSourceLevels {
                for source in controllableMainMixSources where levels.indices.contains(source) {
                    writeMainMixSourceLevel(source: source, db: levels[source])
                    setMainMixSourceLevelLocally(source: source, db: levels[source])
                }
            }
            preSoloMainMixSourceLevels = nil
            return
        }

        let levels = preSoloMainMixSourceLevels ?? mainMixSourceLevelsDB
        for source in controllableMainMixSources {
            let db = soloedMainMixSources.contains(source) && levels.indices.contains(source) ? levels[source] : -128
            writeMainMixSourceLevel(source: source, db: db)
            setMainMixSourceLevelLocally(source: source, db: db)
        }
    }

    private func mainMixSourceLevel(_ source: Int) -> Double {
        guard mainMixSourceLevelsDB.indices.contains(source) else { return -60 }
        return mainMixSourceLevelsDB[source]
    }

    private func setMainMixSourceLevelLocally(source: Int, db: Double) {
        setSendSourceLevelLocally(source: source, bus: .main, db: db)
    }

    private func setSendSourceLevelLocally(source: Int, bus: Mixer.SendBus, db: Double) {
        guard source >= 0 else { return }
        var levels = sendSourceLevelsDB[bus] ?? []
        if source >= levels.count {
            levels.append(contentsOf: Array(repeating: -128, count: source - levels.count + 1))
        }
        levels[source] = db
        sendSourceLevelsDB[bus] = levels
        guard bus == .main else { return }
        if source >= mainMixSourceLevelsDB.count {
            mainMixSourceLevelsDB.append(contentsOf: Array(repeating: -128, count: source - mainMixSourceLevelsDB.count + 1))
        }
        mainMixSourceLevelsDB[source] = db
        if let peakChannel = model?.peakChannel(forMixerSource: source) {
            if peakChannel < mixerLevelsDB.count {
                mixerLevelsDB[peakChannel] = db
            }
            if let inputCount = model?.totalInputs, peakChannel >= inputCount {
                let dawPair = (peakChannel - inputCount) / 2
                if dawReturnLevelsDB.indices.contains(dawPair) {
                    dawReturnLevelsDB[dawPair] = db
                }
            }
        }
    }

    private func writeMainMixSourceLevel(source: Int, db: Double) {
        guard isControllableMainMixSource(source) else { return }
        guard let device else { return }
        let send = sendControls(source: source, bus: .main)
        guard let send else { return }
        Task {
            _ = try? await device.write(send.left, db)
            _ = try? await device.write(send.right, db)
        }
    }

    private func readOutputRouteSources(outputs: Int) async -> [UInt8?] {
        guard let device, outputs > 0 else { return [] }
        var sources = Array<UInt8?>(repeating: nil, count: outputs)
        for output in 0..<outputs {
            sources[output] = try? await device.read(Routing.source(output: UInt8(output)))
        }
        return sources
    }

    private func setOutputRouteSourceLocally(output: Int, value: UInt8) {
        guard output >= 0 else { return }
        if output >= outputRouteSources.count {
            outputRouteSources.append(contentsOf: Array<UInt8?>(repeating: nil, count: output - outputRouteSources.count + 1))
        }
        outputRouteSources[output] = value
    }

    public var controllableMainMixSources: Set<Int> {
        guard let model else { return [] }
        let displayedDAWChannels = Mixer.dawReturnPairs * 2
        let peakChannels = 0..<(model.totalInputs + displayedDAWChannels)
        var sources: Set<Int> = []
        for peakChannel in peakChannels {
            if let source = model.mixerSource(forPeakChannel: peakChannel) {
                sources.insert(source)
            }
        }
        return sources.filter(isSafeMixerSource)
    }

    public func isControllableMainMixSource(_ source: Int) -> Bool {
        controllableMainMixSources.contains(source)
    }

    public func mixerSource(forPeakChannel index: Int) -> Int? {
        guard let source = model?.mixerSource(forPeakChannel: index),
              isControllableMainMixSource(source) else { return nil }
        return source
    }

    private func sendControls(source: Int, bus: Mixer.SendBus) -> (left: FixedQ88Control, right: FixedQ88Control)? {
        if isDAWInputMixerSource(source) {
            return Mixer.dawSend(source: UInt8(source), bus: bus)
        }
        return Mixer.send(source: UInt8(source), bus: bus)
    }

    private func isDAWInputMixerSource(_ source: Int) -> Bool {
        guard let model else { return false }
        let firstDAWSource = model.totalInputs
        return source >= firstDAWSource && source < firstDAWSource + Mixer.dawReturnPairs * 2
    }

    private func isSafeMixerSource(_ source: Int) -> Bool {
        guard source >= 0 else { return false }
        let stride = isDAWInputMixerSource(source) ? Mixer.slotsPerDAWInput : Mixer.slotsPerInput
        return source * Int(stride) + Int(Mixer.mainRightSlot) <= Int(UInt8.max)
    }

    private func apply<C: Control>(_ control: C, _ value: C.Value, update: () -> Void) {
        update()
        guard let device else { return }
        Task { _ = try? await device.write(control, value) }
    }
}
