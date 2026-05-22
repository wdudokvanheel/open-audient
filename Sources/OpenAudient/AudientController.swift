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
    @Published public var mutedMainMixSources: Set<Int> = []
    @Published public var soloedMainMixSources: Set<Int> = []

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
        mutedMainMixSources = []
        soloedMainMixSources = []
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

        let inputs = model?.micInputs ?? 0
        let sourceCount = model?.peakMeterChannels ?? max(inputs, 1)
        var sourceLevels = Array(repeating: -60.0, count: sourceCount)
        for source in controllableMainMixSources {
            let left = Mixer.mainSend(source: UInt8(source)).left
            sourceLevels[source] = (try? await device.read(left)) ?? -60
        }
        mainMixSourceLevelsDB = sourceLevels
        mutedMainMixSources = mutedMainMixSources.intersection(controllableMainMixSources)

        var levels: [Double] = []
        for input in 0..<inputs {
            levels.append(sourceLevels.indices.contains(input) ? sourceLevels[input] : -128)
        }
        mixerLevelsDB = levels

        let inputCount = UInt8(model?.totalInputs ?? inputs)
        var dawLevels: [Double] = []
        for pair in 0..<Mixer.dawReturnPairs {
            let source = Int(inputCount) + pair * 2
            dawLevels.append(sourceLevels.indices.contains(source) ? sourceLevels[source] : -128)
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
        setMainMixSourceLevel(source: input, db: db)
    }

    /// Set a DAW return pair's level in the main mix (writes both L and R sends).
    public func setDAWReturnLevel(pair: Int, db: Double) {
        if pair < dawReturnLevelsDB.count { dawReturnLevelsDB[pair] = db }
        let inputCount = UInt8(model?.totalInputs ?? mixerLevelsDB.count)
        let sources = Mixer.dawReturnSources(pair: UInt8(pair), afterInputCount: inputCount)
        setMainMixSourceLevel(source: Int(sources.left), db: db)
        setMainMixSourceLevel(source: Int(sources.right), db: db)
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
        guard source >= 0 else { return }
        if source >= mainMixSourceLevelsDB.count {
            mainMixSourceLevelsDB.append(contentsOf: Array(repeating: -128, count: source - mainMixSourceLevelsDB.count + 1))
        }
        mainMixSourceLevelsDB[source] = db
        if source < mixerLevelsDB.count {
            mixerLevelsDB[source] = db
        }
        if let inputCount = model?.totalInputs {
            let dawPair = (source - inputCount) / 2
            if source >= inputCount, dawReturnLevelsDB.indices.contains(dawPair) {
                dawReturnLevelsDB[dawPair] = db
            }
        }
    }

    private func writeMainMixSourceLevel(source: Int, db: Double) {
        guard isControllableMainMixSource(source) else { return }
        guard let device else { return }
        let send = Mixer.mainSend(source: UInt8(source))
        Task {
            _ = try? await device.write(send.left, db)
            _ = try? await device.write(send.right, db)
        }
    }

    public var controllableMainMixSources: Set<Int> {
        guard let model else { return [] }
        var sources = Set(0..<model.micInputs)
        let inputCount = model.totalInputs
        for pair in 0..<Mixer.dawReturnPairs {
            let left = inputCount + pair * 2
            sources.insert(left)
            sources.insert(left + 1)
        }
        return sources.filter(isSafeMixerSource)
    }

    public func isControllableMainMixSource(_ source: Int) -> Bool {
        controllableMainMixSources.contains(source)
    }

    private func isSafeMixerSource(_ source: Int) -> Bool {
        source >= 0 && source * Int(Mixer.slotsPerInput) + Int(Mixer.mainRightSlot) <= Int(UInt8.max)
    }

    private func apply<C: Control>(_ control: C, _ value: C.Value, update: () -> Void) {
        update()
        guard let device else { return }
        Task { _ = try? await device.write(control, value) }
    }
}
