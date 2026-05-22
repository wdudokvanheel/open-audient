import Foundation
import Combine

/// High-frequency input peak levels (dBFS), kept separate from `AudientController`
/// so the ~20 Hz meter updates only re-render the meter views, not the whole UI.
@MainActor
public final class MeterReadings: ObservableObject {
    @Published public var inputsDB: [Float] = []
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

    /// Live input peak meters (separate object to avoid re-rendering the whole UI).
    public let meters = MeterReadings()

    /// How often the input meters are polled.
    public var meterInterval: Duration = .milliseconds(50)

    private var device: AudientDevice?
    private let monitor = DeviceMonitor()
    private var monitorTask: Task<Void, Never>?
    private var meterTask: Task<Void, Never>?

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
            startMeters(channels: model.micInputs)
        } catch {
            device = nil
            connection = .error("\(error)")
        }
    }

    private func handleDisconnected() {
        meterTask?.cancel()
        meterTask = nil
        meters.inputsDB = []
        device = nil
        connection = .disconnected
    }

    private func startMeters(channels: Int) {
        meterTask?.cancel()
        guard channels > 0 else { return }
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let device = self.device else { return }
                if let levels = try? await device.readInputMeters(channels: channels) {
                    self.meters.inputsDB = levels
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
        var levels: [Double] = []
        for input in 0..<inputs {
            let left = Mixer.mainSend(input: UInt8(input)).left
            levels.append((try? await device.read(left)) ?? -128)
        }
        mixerLevelsDB = levels
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
        guard let device else { return }
        let send = Mixer.mainSend(input: UInt8(input))
        Task {
            _ = try? await device.write(send.left, db)
            _ = try? await device.write(send.right, db)
        }
    }

    private func apply<C: Control>(_ control: C, _ value: C.Value, update: () -> Void) {
        update()
        guard let device else { return }
        Task { _ = try? await device.write(control, value) }
    }
}
