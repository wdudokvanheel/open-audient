/// Monitor **Cut** — mutes the main speaker output while leaving headphones live.
///
/// Verified against Audient iD.app v4.4.2's `UacXUAudientMonitorController::setCut`:
/// selector 4, monitor extension unit 0x36, channel 0, 1-byte payload
/// (0x01 = cut on / speakers muted, 0x00 = cut off / speakers live).
public struct CutControl: Control {
    public typealias Value = Bool

    public init() {}

    public let name = "Cut"

    public var request: UACControlRequest {
        UACControlRequest(unitID: 0x36, selector: 0x04, channel: 0, interface: 0, length: 1)
    }

    public func encode(_ value: Bool) -> [UInt8] { [value ? 0x01 : 0x00] }

    public func decode(_ bytes: [UInt8]) -> Bool { (bytes.first ?? 0) != 0 }
}
