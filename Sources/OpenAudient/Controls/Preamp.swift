/// Per-input preamp controls on the input feature unit (`0x0b`).
///
/// These are UAC2-standard feature-unit controls — Input Gain (`0x0b`), Input
/// Gain Pad (`0x0c`), Phase Inverter (`0x0d`) — recovered from
/// `UacLib::UacFeatureUnit::setInputGain`/`setPhaseInverter`. The `input` is the
/// 1-based channel (1…4 on the iD44; channel 0 is the master).
///
/// They are **write-only** over USB: `GET_CUR` stalls, so values can't be read
/// back (the iD app caches state). The unit ID `0x0b` and the phase selector
/// were confirmed on hardware (a `SET_CUR` ACKs), and match the MixiD project;
/// gain and pad share the same feature unit by UAC2 convention but have not been
/// individually exercised on hardware (writing them changes input levels).
public enum Preamp {
    public static let unit: UInt8 = 0x0B
    public static let gainSelector: UInt8 = 0x0B
    public static let padSelector: UInt8 = 0x0C
    public static let phaseSelector: UInt8 = 0x0D

    /// Input gain in dB (signed Q8.8). Write-only.
    public static func gain(input: UInt8) -> FixedQ88Control {
        FixedQ88Control(
            name: "Gain[\(input)]",
            request: UACControlRequest(unitID: unit, selector: gainSelector, channel: input, length: 2)
        )
    }

    /// Input pad (attenuation) on/off. Write-only.
    public static func pad(input: UInt8) -> BoolControl {
        BoolControl(
            name: "Pad[\(input)]",
            request: UACControlRequest(unitID: unit, selector: padSelector, channel: input, length: 1)
        )
    }

    /// Phase/polarity invert on/off. Write-only. Hardware-confirmed.
    public static func phase(input: UInt8) -> BoolControl {
        BoolControl(
            name: "Phase[\(input)]",
            request: UACControlRequest(unitID: unit, selector: phaseSelector, channel: input, length: 1)
        )
    }
}
