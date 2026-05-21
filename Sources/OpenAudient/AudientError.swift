import Foundation

/// Errors surfaced by the control library. Underlying `IOReturn`/`NSError`
/// values are wrapped rather than leaked to callers.
public enum AudientError: Error, CustomStringConvertible {
    /// No matching device was found on the USB bus.
    case deviceNotFound(USBIdentifier)
    /// The device matched but could not be opened (often: the Audient iD app
    /// still holds it — quit it first).
    case openFailed(underlying: Error?)
    /// A control transfer failed.
    case transferFailed(request: String, underlying: Error?)

    public var description: String {
        switch self {
        case .deviceNotFound(let id):
            return "device not found (\(id))"
        case .openFailed(let underlying):
            let detail = underlying.map { " — \($0)" } ?? ""
            return "could not open device (quit the Audient iD app first)\(detail)"
        case .transferFailed(let request, let underlying):
            let detail = underlying.map { " — \($0)" } ?? ""
            return "\(request) transfer failed\(detail)"
        }
    }
}
