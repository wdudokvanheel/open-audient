import Foundation

/// Peak metering. The mixer unit (`0x3c`) returns an array of little-endian
/// `UInt16` peak sample magnitudes via a block "memory" read (`bRequest 0x03`,
/// offset 0). On the iD44 the first channels are the mic-preamp inputs. Values
/// convert to dBFS as `20·log10(peak / 32768)`.
public enum Meters {
    public static let mixerUnit: UInt8 = 0x3C

    /// Parse little-endian `UInt16` peak values from a meter block.
    public static func peaks(_ bytes: [UInt8]) -> [UInt16] {
        guard bytes.count >= 2 else { return [] }
        return stride(from: 0, to: bytes.count - 1, by: 2).map {
            UInt16(bytes[$0]) | (UInt16(bytes[$0 + 1]) << 8)
        }
    }

    /// Convert a raw peak (0…32768) to dBFS, floored at `floor`.
    public static func dBFS(_ peak: UInt16, floor: Float = -60) -> Float {
        guard peak > 0 else { return floor }
        return max(20 * log10(Float(peak) / 32768), floor)
    }
}
