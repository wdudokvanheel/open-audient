/// A declarative description of one device control.
///
/// A control knows *where* it lives on the device (`request`) and *how* to
/// translate between its Swift value type and the raw bytes on the wire
/// (`encode`/`decode`). Adding a new control — Dim, Mono, monitor volume,
/// phantom power, a fader — is purely a matter of declaring another conformer;
/// no transport plumbing changes.
public protocol Control {
    /// The Swift-facing value type for this control (e.g. `Bool` for a switch).
    associatedtype Value

    /// Human-readable name, used in logs and the eventual UI.
    var name: String { get }

    /// Where the control lives on the device.
    var request: UACControlRequest { get }

    /// Encode a value into the bytes sent in a SET_CUR transfer.
    func encode(_ value: Value) -> [UInt8]

    /// Decode the bytes returned by a GET_CUR transfer.
    func decode(_ bytes: [UInt8]) -> Value
}
