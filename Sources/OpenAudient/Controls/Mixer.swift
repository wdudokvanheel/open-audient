/// The hardware mixer (mixer unit `0x3c`). Crosspoint levels use selector
/// `0x01`, addressed by mixer channel, as signed Q8.8 dB (`0x8000` = `-128` dB =
/// muted/min). Mapping cross-checked against the MixiD project and verified
/// readable on the iD44.
public enum Mixer {
    public static let unit: UInt8 = 0x3C
    public static let secondaryUnit: UInt8 = 0x3D
    public static let levelSelector: UInt8 = 0x01
    public static let dawReturnPairs = 2

    /// Level of a single mixer channel (crosspoint), in dB.
    public static func level(unit: UInt8 = unit, channel: UInt8) -> FixedQ88Control {
        FixedQ88Control(
            name: String(format: "Mixer Level[0x%02x:%d]", unit, channel),
            request: UACControlRequest(unitID: unit, selector: levelSelector, channel: channel, length: 2)
        )
    }

    /// Hardware mixer sources occupy 6 consecutive output slots: Cue A L/R,
    /// Cue B L/R, then Main Mix L/R.
    public static let slotsPerInput: UInt8 = 6
    /// Cue C/D are exposed by the next mixer unit as two stereo outputs.
    public static let slotsPerSecondaryInput: UInt8 = 4
    public static let secondaryChannelCount: UInt8 = 0x3C
    /// DAW mixer sources use a separate 8-slot map, verified around source 20.
    public static let slotsPerDAWInput: UInt8 = 8
    public static let mainLeftSlot: UInt8 = 4
    public static let mainRightSlot: UInt8 = 5

    public enum SendBus: Int, CaseIterable, Identifiable, Sendable {
        case main
        case cueA
        case cueB
        case cueC
        case cueD

        public var id: Int { rawValue }

        public var title: String {
            switch self {
            case .main: return "Main"
            case .cueA: return "Cue A"
            case .cueB: return "Cue B"
            case .cueC: return "Cue C"
            case .cueD: return "Cue D"
            }
        }

        public var longTitle: String {
            switch self {
            case .main: return "Main Mix"
            case .cueA: return "Cue A"
            case .cueB: return "Cue B"
            case .cueC: return "Cue C"
            case .cueD: return "Cue D"
            }
        }

        public var hasSourceLevelControls: Bool {
            levelMap != nil
        }

        var levelMap: (unit: UInt8, stride: UInt8, left: UInt8, right: UInt8)? {
            switch self {
            case .cueA: return (unit, slotsPerInput, 0, 1)
            case .cueB: return (unit, slotsPerInput, 2, 3)
            case .main: return (unit, slotsPerInput, mainLeftSlot, mainRightSlot)
            case .cueC: return (secondaryUnit, slotsPerSecondaryInput, 0, 1)
            case .cueD: return (secondaryUnit, slotsPerSecondaryInput, 2, 3)
            }
        }
    }

    public static func sendChannels(source: UInt8, bus: SendBus) -> (unit: UInt8, left: UInt8, right: UInt8)? {
        guard let map = bus.levelMap else { return nil }
        let base = source &* map.stride
        let channels = (unit: map.unit, left: base &+ map.left, right: base &+ map.right)
        if channels.unit == secondaryUnit, channels.right >= secondaryChannelCount {
            return nil
        }
        return channels
    }

    public static func send(source: UInt8, bus: SendBus) -> (left: FixedQ88Control, right: FixedQ88Control)? {
        guard let channels = sendChannels(source: source, bus: bus) else { return nil }
        return (level(unit: channels.unit, channel: channels.left), level(unit: channels.unit, channel: channels.right))
    }

    /// DAW input sources use an 8-slot stride where the first two stereo buses
    /// are ordered Main, then Cue A.
    public static func dawSendChannels(source: UInt8, bus: SendBus) -> (unit: UInt8, left: UInt8, right: UInt8)? {
        let unit: UInt8
        let stride: UInt8
        let slots: (left: UInt8, right: UInt8)
        switch bus {
        case .main:
            unit = Mixer.unit
            stride = slotsPerDAWInput
            slots = (0, 1)
        case .cueA:
            unit = Mixer.unit
            stride = slotsPerDAWInput
            slots = (2, 3)
        case .cueB:
            unit = Mixer.unit
            stride = slotsPerDAWInput
            slots = (4, 5)
        case .cueC, .cueD:
            return nil
        }
        let base = source &* stride
        return (unit: unit, left: base &+ slots.left, right: base &+ slots.right)
    }

    public static func dawSend(source: UInt8, bus: SendBus) -> (left: FixedQ88Control, right: FixedQ88Control)? {
        guard let channels = dawSendChannels(source: source, bus: bus) else { return nil }
        return (level(unit: channels.unit, channel: channels.left), level(unit: channels.unit, channel: channels.right))
    }

    /// The main-mix L/R crosspoint channels for a mixer source (0-based).
    public static func mainSendChannels(source: UInt8) -> (left: UInt8, right: UInt8) {
        let channels = sendChannels(source: source, bus: .main)!
        return (channels.left, channels.right)
    }

    /// The main-mix L/R crosspoint channels for an input (0-based).
    public static func mainSendChannels(input: UInt8) -> (left: UInt8, right: UInt8) {
        mainSendChannels(source: input)
    }

    /// The main-mix L/R level controls for a mixer source.
    public static func mainSend(source: UInt8) -> (left: FixedQ88Control, right: FixedQ88Control) {
        send(source: source, bus: .main)!
    }

    /// The main-mix L/R level controls for an input.
    public static func mainSend(input: UInt8) -> (left: FixedQ88Control, right: FixedQ88Control) {
        mainSend(source: input)
    }

    /// DAW return channels follow the hardware input sources in the iD44 mixer
    /// source map.
    public static func dawReturnSources(pair: UInt8, afterInputCount inputCount: UInt8) -> (left: UInt8, right: UInt8) {
        let left = inputCount &+ pair &* 2
        return (left: left, right: left &+ 1)
    }

    /// The main-mix L/R crosspoint channels for DAW 1+2 / 3+4 return pairs.
    public static func dawReturnChannels(pair: UInt8, afterInputCount inputCount: UInt8) -> (left: (left: UInt8, right: UInt8), right: (left: UInt8, right: UInt8)) {
        let sources = dawReturnSources(pair: pair, afterInputCount: inputCount)
        let left = dawSendChannels(source: sources.left, bus: .main)!
        let right = dawSendChannels(source: sources.right, bus: .main)!
        return (
            left: (left.left, left.right),
            right: (right.left, right.right)
        )
    }

    /// The main-mix L/R level controls for DAW 1+2 / 3+4 return pairs.
    public static func dawReturn(pair: UInt8, afterInputCount inputCount: UInt8) -> (left: (left: FixedQ88Control, right: FixedQ88Control), right: (left: FixedQ88Control, right: FixedQ88Control)) {
        let sources = dawReturnSources(pair: pair, afterInputCount: inputCount)
        return (
            left: dawSend(source: sources.left, bus: .main)!,
            right: dawSend(source: sources.right, bus: .main)!
        )
    }
}
