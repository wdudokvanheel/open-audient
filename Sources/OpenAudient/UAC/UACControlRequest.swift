/// Addresses a single USB Audio Class (UAC) control on an extension/feature unit.
///
/// The control protocol packs its addressing into the standard `wValue` /
/// `wIndex` fields of a USB control transfer:
///
///     wValue = (controlSelector << 8) | channel
///     wIndex = (unitID << 8) | interface
///
/// For the iD44 Cut control these resolve to `wValue = 0x0400` and
/// `wIndex = 0x3600` (selector 4, unit 0x36, channel 0, interface 0).
public struct UACControlRequest: Equatable, Sendable {
    /// Extension/feature unit ID (high byte of `wIndex`).
    public let unitID: UInt8
    /// Control selector (high byte of `wValue`).
    public let selector: UInt8
    /// Logical channel (low byte of `wValue`); 0 = master.
    public let channel: UInt8
    /// Audio control interface number (low byte of `wIndex`).
    public let interface: UInt8
    /// Payload length in bytes (`wLength`).
    public let length: UInt16

    public init(
        unitID: UInt8,
        selector: UInt8,
        channel: UInt8 = 0,
        interface: UInt8 = 0,
        length: UInt16
    ) {
        self.unitID = unitID
        self.selector = selector
        self.channel = channel
        self.interface = interface
        self.length = length
    }

    public var wValue: UInt16 { (UInt16(selector) << 8) | UInt16(channel) }
    public var wIndex: UInt16 { (UInt16(unitID) << 8) | UInt16(interface) }
}
