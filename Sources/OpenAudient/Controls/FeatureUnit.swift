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

/// Headphone output (feature unit `0x0a`). Verified readable on the iD44.
public enum Headphones {
    public static let unit: UInt8 = 0x0A
    public static let leftVolume = FeatureUnit.volume(unit: unit, channel: 3)
    public static let rightVolume = FeatureUnit.volume(unit: unit, channel: 4)
    public static let leftMute = FeatureUnit.mute(unit: unit, channel: 3)
    public static let rightMute = FeatureUnit.mute(unit: unit, channel: 4)
}
