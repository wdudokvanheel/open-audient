/// High-level facade over an Audient device.
///
/// Reads and writes are expressed in terms of typed `Control` descriptors, so
/// callers never touch raw bytes or USB request fields:
///
///     let device = try AudientDevice.openFirst()
///     let muted = try device.read(CutControl())
///     try device.write(CutControl(), true)
///     try device.toggle(CutControl())
public final class AudientDevice {
    public let transport: USBControlTransport

    public init(transport: USBControlTransport) {
        self.transport = transport
    }

    /// Discover and open the first connected device of the given identity.
    public static func openFirst(_ identifier: USBIdentifier = .iD44) throws -> AudientDevice {
        AudientDevice(transport: try IOUSBHostTransport(identifier: identifier))
    }

    /// Read the current value of a control.
    public func read<C: Control>(_ control: C) throws -> C.Value {
        control.decode(try transport.getCurrent(control.request))
    }

    /// Write a value to a control. Returns the value written for chaining.
    @discardableResult
    public func write<C: Control>(_ control: C, _ value: C.Value) throws -> C.Value {
        try transport.setCurrent(control.request, data: control.encode(value))
        return value
    }

    /// Flip a boolean control and return its new value.
    @discardableResult
    public func toggle<C: Control>(_ control: C) throws -> Bool where C.Value == Bool {
        try write(control, !(try read(control)))
    }

    // MARK: Raw access (for diagnostics and protocol mapping)

    /// Issue a raw GET_CUR. Returns the bytes read.
    public func getRaw(unit: UInt8, selector: UInt8, channel: UInt8 = 0, length: UInt16) throws -> [UInt8] {
        try transport.getCurrent(
            UACControlRequest(unitID: unit, selector: selector, channel: channel, length: length)
        )
    }

    /// Issue a raw SET_CUR.
    public func setRaw(unit: UInt8, selector: UInt8, channel: UInt8 = 0, data: [UInt8]) throws {
        try transport.setCurrent(
            UACControlRequest(unitID: unit, selector: selector, channel: channel, length: UInt16(data.count)),
            data: data
        )
    }
}
