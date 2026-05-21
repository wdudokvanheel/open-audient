import Foundation

/// A 1-byte boolean control (0/1). Used for switches like Cut, Dim, Mono.
public struct BoolControl: Control {
    public typealias Value = Bool
    public let name: String
    public let request: UACControlRequest

    public init(name: String, request: UACControlRequest) {
        self.name = name
        self.request = request
    }

    public func encode(_ value: Bool) -> [UInt8] { [value ? 0x01 : 0x00] }
    public func decode(_ bytes: [UInt8]) -> Bool { (bytes.first ?? 0) != 0 }
}

/// A 1-byte unsigned enumeration/index control (e.g. Source, MonitorOutputSel).
public struct ByteControl: Control {
    public typealias Value = UInt8
    public let name: String
    public let request: UACControlRequest

    public init(name: String, request: UACControlRequest) {
        self.name = name
        self.request = request
    }

    public func encode(_ value: UInt8) -> [UInt8] { [value] }
    public func decode(_ bytes: [UInt8]) -> UInt8 { bytes.first ?? 0 }
}

/// A signed Q8.8 fixed-point control transferred as a little-endian `Int16`
/// (`raw = round(value × 256)`). Audient encodes monitor volumes and
/// attenuations this way — the iD app converts the `double` with
/// `fcvtzs w8, d0, #8` before sending two bytes.
public struct FixedQ88Control: Control {
    public typealias Value = Double
    public let name: String
    public let request: UACControlRequest

    public init(name: String, request: UACControlRequest) {
        self.name = name
        self.request = request
    }

    public func encode(_ value: Double) -> [UInt8] {
        let raw = Int16(clamping: Int((value * 256.0).rounded()))
        let bits = UInt16(bitPattern: raw).littleEndian
        return [UInt8(bits & 0xFF), UInt8(bits >> 8)]
    }

    public func decode(_ bytes: [UInt8]) -> Double {
        guard bytes.count >= 2 else { return 0 }
        let bits = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
        return Double(Int16(bitPattern: bits)) / 256.0
    }
}
