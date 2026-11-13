import Foundation

/// Peak metering. The mixer unit (`0x3c`) returns an array of little-endian
/// `UInt16` peak sample magnitudes via a block "memory" read (`bRequest 0x03`,
/// offset 0). On the iD44 the first channels are the mic-preamp inputs.
///
/// Peaks use the full unsigned 16-bit range: `0xFFFF` is 0 dBFS. Measured on an
/// iD44 with a test tone on DAW playback, a -20 dBFS sine reads ~`0x1999` and a
/// -0.9 dBFS sine reads ~`0xE666`.
public enum Meters {
    public static let mixerUnit: UInt8 = 0x3C

    /// Raw peak value corresponding to 0 dBFS.
    public static let fullScale = Float(UInt16.max)

    /// Parse little-endian `UInt16` peak values from a meter block.
    public static func peaks(_ bytes: [UInt8]) -> [UInt16] {
        guard bytes.count >= 2 else { return [] }
        return stride(from: 0, to: bytes.count - 1, by: 2).map {
            UInt16(bytes[$0]) | (UInt16(bytes[$0 + 1]) << 8)
        }
    }

    /// Convert a raw peak (0…65535) to dBFS, floored at `floor`.
    public static func dBFS(_ peak: UInt16, floor: Float = -60) -> Float {
        guard peak > 0 else { return floor }
        return max(20 * log10(Float(peak) / fullScale), floor)
    }
}
