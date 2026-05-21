import Foundation
import IOKit

/// Locates Audient hardware in the IORegistry.
///
/// The kernel already represents the iD44 as an `IOUSBHostDevice`, so we match
/// on that class plus the `idVendor`/`idProduct` properties.
public enum DeviceDiscovery {
    /// Return the first matching `io_service_t`. The caller owns the returned
    /// object and must `IOObjectRelease` it.
    public static func matchFirst(_ id: USBIdentifier) throws -> io_service_t {
        guard let matching = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary? else {
            throw AudientError.deviceNotFound(id)
        }
        matching["idVendor"] = id.vendorID
        matching["idProduct"] = id.productID

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else {
            throw AudientError.deviceNotFound(id)
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != IO_OBJECT_NULL else {
            throw AudientError.deviceNotFound(id)
        }
        return service
    }
}
