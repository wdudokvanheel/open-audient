/// Output routing matrix (extension unit `0x33`). Each output channel's source
/// is a single byte selected via selector `0x06`, with the output index carried
/// in the channel byte. Verified readable on the iD44 (outputs report distinct
/// source IDs). Main/alt routing is cross-checked against the MixiD project;
/// cue output routing follows the official iD44 client, which writes stereo cue
/// source pairs. Older repeated cue bytes are still recognized when reading.
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
                return Self.cueValue(index: 0, output: output)
            case .cueB:
                return Self.cueValue(index: 1, output: output)
            case .cueC:
                return Self.cueValue(index: 2, output: output)
            case .cueD:
                return Self.cueValue(index: 3, output: output)
            case .dawThru:
                return UInt8(clamping: output)
            }
        }

        public static func matching(leftOutput: Int, leftValue: UInt8, rightValue: UInt8) -> Source? {
            if let source = legacyCueSource(leftValue: leftValue, rightValue: rightValue) {
                return source
            }
            if let source = stereoPairCueSource(leftValue: leftValue, rightValue: rightValue) {
                return source
            }
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

        private static func legacyCueSource(leftValue: UInt8, rightValue: UInt8) -> Source? {
            switch (leftValue, rightValue) {
            case (0x19, 0x19): return .cueA
            case (0x1a, 0x1a): return .cueB
            case (0x1f, 0x1f): return .cueC
            case (0x20, 0x20): return .cueD
            default: return nil
            }
        }

        private static func cueValue(index: Int, output: Int) -> UInt8 {
            UInt8(0x2e + index * 2 + (output.isMultiple(of: 2) ? 0 : 1))
        }

        private static func stereoPairCueSource(leftValue: UInt8, rightValue: UInt8) -> Source? {
            switch (leftValue, rightValue) {
            case (0x2e, 0x2f): return .cueA
            case (0x30, 0x31): return .cueB
            case (0x32, 0x33): return .cueC
            case (0x34, 0x35): return .cueD
            default: return nil
            }
        }
    }

    /// The source feeding a given output channel. Value is a device source ID.
    ///
    /// On the iD44 outputs are `0x00`…`0x17`: line 1–4, HP 1 L/R, HP 2 L/R,
    /// then ADAT 1–16 (`DeviceModel.totalOutputs`). Stay within that range:
    /// a `GET_CUR` on output `0x18` times out and leaves the device's control
    /// endpoint unresponsive until it is power-cycled.
    public static func source(output: UInt8) -> ByteControl {
        ByteControl(
            name: "Route Source[\(output)]",
            request: UACControlRequest(unitID: unit, selector: sourceSelector, channel: output, length: 1)
        )
    }
}
