/// Output routing matrix (extension unit `0x33`). Each output channel's source
/// is a single byte selected via selector `0x06`, with the output index carried
/// in the channel byte. Verified readable on the iD44 (outputs report distinct
/// source IDs); mapping cross-checked against the MixiD project.
public enum Routing {
    public static let unit: UInt8 = 0x33
    public static let sourceSelector: UInt8 = 0x06

    /// The source feeding a given output channel (0…5 on the iD44: Main L/R,
    /// then headphones/alt pairs). Value is a device source ID.
    public static func source(output: UInt8) -> ByteControl {
        ByteControl(
            name: "Route Source[\(output)]",
            request: UACControlRequest(unitID: unit, selector: sourceSelector, channel: output, length: 1)
        )
    }
}
