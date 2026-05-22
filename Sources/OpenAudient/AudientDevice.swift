import Foundation

/// An open connection to an Audient device.
///
/// All control transfers are serialized on a private background queue, so calls
/// never block the caller's thread (e.g. SwiftUI's main actor). Reads and writes
/// are expressed in terms of typed `Control` descriptors:
///
///     let device = try await AudientDevice.openFirst()
///     try await device.write(Monitor.cut, true)
///     let volume = try await device.read(Monitor.mainVolume)
///
/// The type is `@unchecked Sendable`: every access to the underlying transport
/// goes through the serial queue, which provides the required synchronization.
public final class AudientDevice: @unchecked Sendable {
    /// The model this connection is talking to.
    public let model: DeviceModel

    private let transport: USBControlTransport
    private let queue = DispatchQueue(label: "com.openaudient.device", qos: .userInitiated)

    public init(transport: USBControlTransport, model: DeviceModel = .iD44) {
        self.transport = transport
        self.model = model
    }

    /// Discover and open the first connected device of the given model.
    public static func openFirst(_ model: DeviceModel = .iD44) async throws -> AudientDevice {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result {
                    AudientDevice(transport: try IOUSBHostTransport(identifier: model.identifier), model: model)
                })
            }
        }
    }

    // MARK: Typed controls

    /// Read the current value of a control.
    public func read<C: Control>(_ control: C) async throws -> C.Value {
        try await perform { control.decode(try $0.getCurrent(control.request)) }
    }

    /// Write a value to a control. Returns the value written, for chaining.
    @discardableResult
    public func write<C: Control>(_ control: C, _ value: C.Value) async throws -> C.Value {
        try await perform { try $0.setCurrent(control.request, data: control.encode(value)); return value }
    }

    /// Flip a boolean control and return its new value.
    @discardableResult
    public func toggle<C: Control>(_ control: C) async throws -> Bool where C.Value == Bool {
        try await write(control, !(try await read(control)))
    }

    // MARK: Raw access (diagnostics / protocol mapping)

    public func getRaw(unit: UInt8, selector: UInt8, channel: UInt8 = 0, length: UInt16) async throws -> [UInt8] {
        try await perform {
            try $0.getCurrent(UACControlRequest(unitID: unit, selector: selector, channel: channel, length: length))
        }
    }

    public func setRaw(unit: UInt8, selector: UInt8, channel: UInt8 = 0, data: [UInt8]) async throws {
        try await perform {
            try $0.setCurrent(UACControlRequest(unitID: unit, selector: selector, channel: channel, length: UInt16(data.count)), data: data)
        }
    }

    /// Read a block "memory" region (e.g. meters).
    public func readMemory(unit: UInt8, offset: UInt16 = 0, length: UInt16) async throws -> [UInt8] {
        try await perform { try $0.getMemory(unitID: unit, offset: offset, length: length) }
    }

    /// Read peak meters as dBFS, one per channel.
    public func readPeakMeters(channels: Int) async throws -> [Float] {
        let bytes = try await readMemory(unit: Meters.mixerUnit, offset: 0, length: UInt16(channels * 2))
        return Meters.peaks(bytes).map { Meters.dBFS($0) }
    }

    /// Read input peak meters as dBFS, one per channel.
    public func readInputMeters(channels: Int) async throws -> [Float] {
        try await readPeakMeters(channels: channels)
    }

    /// Run a transport operation on the device's serial queue.
    private func perform<T>(_ body: @escaping (USBControlTransport) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [transport] in
                continuation.resume(with: Result { try body(transport) })
            }
        }
    }
}
