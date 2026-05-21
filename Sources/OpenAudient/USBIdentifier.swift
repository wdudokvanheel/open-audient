/// A USB device identity used to locate hardware on the bus.
public struct USBIdentifier: Equatable, Sendable {
    public let vendorID: Int
    public let productID: Int

    public init(vendorID: Int, productID: Int) {
        self.vendorID = vendorID
        self.productID = productID
    }

    /// Audient iD44 (VID 0x2708, PID 0x0005).
    public static let iD44 = USBIdentifier(vendorID: 0x2708, productID: 0x0005)
}

extension USBIdentifier: CustomStringConvertible {
    public var description: String {
        String(format: "VID 0x%04X / PID 0x%04X", vendorID, productID)
    }
}
