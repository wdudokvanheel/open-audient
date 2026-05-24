/// Output routing matrix (extension unit `0x33`). Each output channel's source
/// is a single byte selected via selector `0x06`, with the output index carried
/// in the channel byte. Verified readable on the iD44 (outputs report distinct
/// source IDs); mapping cross-checked against the MixiD project.
public enum Routing {
    public static let unit: UInt8 = 0x33
    public static let sourceSelector: UInt8 = 0x06

    public enum Source: Int, CaseIterable, Identifiable, Sendable {
        case mainMix
        case altSpeaker
        case cueA
        case cueB
        case cueC
        case cueD
        case dawThru

        public var id: Int { rawValue }

        public var title: String {
            switch self {
            case .mainMix: return "Main Mix"
            case .altSpeaker: return "Alt Spk"
            case .cueA: return "Cue A"
            case .cueB: return "Cue B"
            case .cueC: return "Cue C"
            case .cueD: return "Cue D"
            case .dawThru: return "DAW Thru"
            }
        }

        public func value(forOutput output: Int) -> UInt8 {
            switch self {
            case .mainMix:
                return output >= 4
                    ? (output.isMultiple(of: 2) ? 0x3f : 0x40)
                    : (output.isMultiple(of: 2) ? 0x3b : 0x3c)
            case .altSpeaker:
                return output.isMultiple(of: 2) ? 0x3d : 0x3e
            case .cueA:
                return 0x19
            case .cueB:
                return 0x1a
            case .cueC:
                return 0x1f
            case .cueD:
                return 0x20
            case .dawThru:
                return UInt8(clamping: output)
            }
        }

        public static func matching(leftOutput: Int, leftValue: UInt8, rightValue: UInt8) -> Source? {
            if (leftValue, rightValue) == (0x1b, 0x1c) ||
                (leftValue, rightValue) == (0x3b, 0x3c) ||
                (leftValue, rightValue) == (0x3f, 0x40) {
                return .mainMix
            }
            return allCases.first {
                leftValue == $0.value(forOutput: leftOutput) &&
                rightValue == $0.value(forOutput: leftOutput + 1)
            }
        }
    }

    /// The source feeding a given output channel (0…5 on the iD44: Main L/R,
    /// then headphones/alt pairs). Value is a device source ID.
    public static func source(output: UInt8) -> ByteControl {
        ByteControl(
            name: "Route Source[\(output)]",
            request: UACControlRequest(unitID: unit, selector: sourceSelector, channel: output, length: 1)
        )
    }
}
