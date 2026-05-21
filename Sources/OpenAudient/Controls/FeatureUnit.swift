/// Standard UAC2 feature-unit controls (mute, volume). The iD44 exposes its
/// analogue/DAW feature units this way; e.g. the headphone output lives on
/// feature unit `0x0a`, channels 3 and 4.
///
/// Per the UAC2 spec, feature-unit control selectors are `MUTE = 0x01` and
/// `VOLUME = 0x02`, and volume is signed Q8.8 dB — the same encoding the monitor
/// unit uses (`-128.0` dB / `0x8000` means muted/minimum).
public enum FeatureUnit {
    public static let muteSelector: UInt8 = 0x01
    public static let volumeSelector: UInt8 = 0x02

    public static func mute(unit: UInt8, channel: UInt8) -> BoolControl {
        BoolControl(
            name: "Mute[\(channel)]",
            request: UACControlRequest(unitID: unit, selector: muteSelector, channel: channel, length: 1)
        )
    }

    public static func volume(unit: UInt8, channel: UInt8) -> FixedQ88Control {
        FixedQ88Control(
            name: "Volume[\(channel)]",
            request: UACControlRequest(unitID: unit, selector: volumeSelector, channel: channel, length: 2)
        )
    }
}

/// Output feature unit `0x0a`, channels 3/4.
///
/// NOTE: on the **iD44** the two headphone outputs have *physical* level dials
/// and are not USB-controllable — writing here does not change them (confirmed on
/// hardware). These controls are kept as generic feature-unit accessors and may
/// map to software-controlled outputs on other iD models, but are not surfaced in
/// the iD44 UI.
public enum Headphones {
    public static let unit: UInt8 = 0x0A
    public static let leftVolume = FeatureUnit.volume(unit: unit, channel: 3)
    public static let rightVolume = FeatureUnit.volume(unit: unit, channel: 4)
    public static let leftMute = FeatureUnit.mute(unit: unit, channel: 3)
    public static let rightMute = FeatureUnit.mute(unit: unit, channel: 4)
}
