/// USB Audio Class control-transfer constants.
///
/// `GET_CUR` and `SET_CUR` share the same `bRequest` (0x01); they differ only
/// in transfer direction, which lives in the high bit of `bmRequestType`.
public enum UACRequestCode {
    /// `bRequest` for both GET_CUR and SET_CUR.
    public static let current: UInt8 = 0x01

    /// `bmRequestType` for SET_CUR: host→device, class request, interface recipient.
    /// 0b0_01_00001 = 0x21
    public static let setRequestType: UInt8 = 0x21

    /// `bmRequestType` for GET_CUR: device→host, class request, interface recipient.
    /// 0b1_01_00001 = 0xA1
    public static let getRequestType: UInt8 = 0xA1

    /// `bRequest` for Audient's block "memory" read used by the meters
    /// (`bmRequestType` 0xA1, returns an array of per-channel peak values).
    public static let memory: UInt8 = 0x03
}
