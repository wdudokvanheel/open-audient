/// The hardware mixer (mixer unit `0x3c`). Crosspoint levels use selector
/// `0x01`, addressed by mixer channel, as signed Q8.8 dB (`0x8000` = `-128` dB =
/// muted/min). Mapping cross-checked against the MixiD project and verified
/// readable on the iD44.
public enum Mixer {
    public static let unit: UInt8 = 0x3C
    public static let levelSelector: UInt8 = 0x01

    /// Level of a single mixer channel (crosspoint), in dB.
    public static func level(channel: UInt8) -> FixedQ88Control {
        FixedQ88Control(
            name: "Mixer Level[\(channel)]",
            request: UACControlRequest(unitID: unit, selector: levelSelector, channel: channel, length: 2)
        )
    }

    /// The left/right mixer channels carrying input `input` (stride of 6 per
    /// input, per MixiD's `set_channel_volume`).
    public static func inputChannels(_ input: UInt8) -> (left: UInt8, right: UInt8) {
        (left: input &* 6, right: input &* 6 &+ 1)
    }
}
