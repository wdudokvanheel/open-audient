/// The hardware mixer (mixer unit `0x3c`). Crosspoint levels use selector
/// `0x01`, addressed by mixer channel, as signed Q8.8 dB (`0x8000` = `-128` dB =
/// muted/min). Mapping cross-checked against the MixiD project and verified
/// readable on the iD44.
public enum Mixer {
    public static let unit: UInt8 = 0x3C
    public static let levelSelector: UInt8 = 0x01
    public static let dawReturnPairs = 2

    /// Level of a single mixer channel (crosspoint), in dB.
    public static func level(channel: UInt8) -> FixedQ88Control {
        FixedQ88Control(
            name: "Mixer Level[\(channel)]",
            request: UACControlRequest(unitID: unit, selector: levelSelector, channel: channel, length: 2)
        )
    }

    /// Each input occupies 6 consecutive crosspoint slots: Cue A L/R, Cue B L/R,
    /// then the **main mix** L/R. Confirmed on hardware (muting an input's slots
    /// 4/5 removes it from the monitored main mix).
    public static let slotsPerInput: UInt8 = 6
    public static let mainLeftSlot: UInt8 = 4
    public static let mainRightSlot: UInt8 = 5

    /// The main-mix L/R crosspoint channels for a mixer source (0-based).
    public static func mainSendChannels(source: UInt8) -> (left: UInt8, right: UInt8) {
        let base = source &* slotsPerInput
        return (left: base &+ mainLeftSlot, right: base &+ mainRightSlot)
    }

    /// The main-mix L/R crosspoint channels for an input (0-based).
    public static func mainSendChannels(input: UInt8) -> (left: UInt8, right: UInt8) {
        mainSendChannels(source: input)
    }

    /// The main-mix L/R level controls for a mixer source.
    public static func mainSend(source: UInt8) -> (left: FixedQ88Control, right: FixedQ88Control) {
        let channels = mainSendChannels(source: source)
        return (level(channel: channels.left), level(channel: channels.right))
    }

    /// The main-mix L/R level controls for an input.
    public static func mainSend(input: UInt8) -> (left: FixedQ88Control, right: FixedQ88Control) {
        mainSend(source: input)
    }

    /// DAW return channels follow the hardware input sources in the mixer source map.
    public static func dawReturnSources(pair: UInt8, afterInputCount inputCount: UInt8) -> (left: UInt8, right: UInt8) {
        let left = inputCount &+ (pair &* 2)
        return (left: left, right: left &+ 1)
    }

    /// The main-mix L/R crosspoint channels for DAW 1+2 / 3+4 return pairs.
    public static func dawReturnChannels(pair: UInt8, afterInputCount inputCount: UInt8) -> (left: (left: UInt8, right: UInt8), right: (left: UInt8, right: UInt8)) {
        let sources = dawReturnSources(pair: pair, afterInputCount: inputCount)
        return (left: mainSendChannels(source: sources.left), right: mainSendChannels(source: sources.right))
    }

    /// The main-mix L/R level controls for DAW 1+2 / 3+4 return pairs.
    public static func dawReturn(pair: UInt8, afterInputCount inputCount: UInt8) -> (left: (left: FixedQ88Control, right: FixedQ88Control), right: (left: FixedQ88Control, right: FixedQ88Control)) {
        let sources = dawReturnSources(pair: pair, afterInputCount: inputCount)
        return (left: mainSend(source: sources.left), right: mainSend(source: sources.right))
    }
}
