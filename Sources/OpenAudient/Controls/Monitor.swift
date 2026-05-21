/// Controls on the Audient monitor extension unit (unit ID `0x36`, extension
/// code 1). Selectors were recovered from
/// `UacLib::UacXUAudientMonitorController`'s setters in iD.app v4.4.2, each of
/// which calls `UacUnitBase::sendSetRequest(SET_CUR, selector, channel, data,
/// length)`. The unit ID is confirmed by the device's USB descriptor (the only
/// extension unit with extension code 1).
public enum Monitor {
    /// Monitor extension unit ID.
    public static let unit: UInt8 = 0x36

    private static func boolControl(_ name: String, _ selector: UInt8) -> BoolControl {
        BoolControl(name: name, request: req(selector, length: 1))
    }
    private static func byteControl(_ name: String, _ selector: UInt8) -> ByteControl {
        ByteControl(name: name, request: req(selector, length: 1))
    }
    private static func fixedControl(_ name: String, _ selector: UInt8, channel: UInt8 = 0) -> FixedQ88Control {
        FixedQ88Control(name: name, request: req(selector, channel: channel, length: 2))
    }
    private static func req(_ selector: UInt8, channel: UInt8 = 0, length: UInt16) -> UACControlRequest {
        UACControlRequest(unitID: unit, selector: selector, channel: channel, length: length)
    }

    // MARK: Switches (1-byte bool)

    public static let mono         = boolControl("Mono", 0x00)         // selector 0x00
    public static let polarity     = boolControl("Polarity", 0x03)     // selector 0x03
    public static let cut          = boolControl("Cut", 0x04)          // selector 0x04
    public static let dim          = boolControl("Dim", 0x05)          // selector 0x05
    public static let talkback     = boolControl("Talkback", 0x07)     // selector 0x07
    public static let hwMonitor    = boolControl("HW Monitor Mode", 0x19) // selector 0x19

    // MARK: Enumerations / indices (1-byte)

    public static let monoMode         = byteControl("Mono Mode", 0x01)          // selector 0x01
    public static let talkbackInput    = byteControl("Talkback Input", 0x08)     // selector 0x08
    public static let monitorOutputSel = byteControl("Monitor Output Sel", 0x0C) // selector 0x0c
    public static let source           = byteControl("Source", 0x15)            // selector 0x15

    // MARK: Levels (signed Q8.8, 2 bytes)

    public static let monoAtten  = fixedControl("Mono Atten", 0x02)   // selector 0x02
    public static let dimAtten   = fixedControl("Dim Atten", 0x06)    // selector 0x06
    public static let mainVolume = fixedControl("Main Volume", 0x12)  // selector 0x12
    public static let cue1Volume = fixedControl("Cue 1 Volume", 0x13) // selector 0x13
    public static let cue2Volume = fixedControl("Cue 2 Volume", 0x14) // selector 0x14

    /// Per-output trim (selector 0x17); the output index is carried in the
    /// channel byte.
    public static func outputTrim(output: UInt8) -> FixedQ88Control {
        fixedControl("Output Trim[\(output)]", 0x17, channel: output)
    }

    /// All read/dump-friendly switches and enums, for diagnostics.
    public static let allSwitches: [BoolControl] = [mono, polarity, cut, dim, talkback, hwMonitor]
    public static let allBytes: [ByteControl] = [monoMode, talkbackInput, monitorOutputSel, source]
    public static let allLevels: [FixedQ88Control] = [monoAtten, dimAtten, mainVolume, cue1Volume, cue2Volume]
}
