import Foundation
import IOKit
import IOUSBHost

/// `USBControlTransport` backed by Apple's modern IOUSBHost framework.
///
/// Control transfers go to endpoint 0, which is not claimed exclusively by the
/// kernel's AppleUSBAudio driver — so CoreAudio keeps streaming while we read
/// and write mixer/monitor state. The Audient iD app must be quit, as it
/// otherwise holds the control endpoint itself.
public final class IOUSBHostTransport: USBControlTransport {
    private let device: IOUSBHostDevice
    private let timeout: TimeInterval

    public init(device: IOUSBHostDevice, timeout: TimeInterval = 1.0) {
        self.device = device
        self.timeout = timeout
    }

    /// Discover and open the first device matching `identifier`.
    public convenience init(identifier: USBIdentifier = .iD44, timeout: TimeInterval = 1.0) throws {
        let service = try DeviceDiscovery.matchFirst(identifier)
        defer { IOObjectRelease(service) }
        do {
            let device = try IOUSBHostDevice(
                __ioService: service,
                options: [],
                queue: nil,
                interestHandler: nil
            )
            self.init(device: device, timeout: timeout)
        } catch {
            throw AudientError.openFailed(underlying: error)
        }
    }

    public func getCurrent(_ control: UACControlRequest) throws -> [UInt8] {
        var request = IOUSBDeviceRequest()
        request.bmRequestType = UACRequestCode.getRequestType
        request.bRequest = UACRequestCode.current
        request.wValue = control.wValue
        request.wIndex = control.wIndex
        request.wLength = control.length

        let buffer = NSMutableData(length: Int(control.length)) ?? NSMutableData()
        let transferred = try send(request, data: buffer, label: "GET_CUR")
        return [UInt8](Data(referencing: buffer).prefix(transferred))
    }

    public func setCurrent(_ control: UACControlRequest, data: [UInt8]) throws {
        var request = IOUSBDeviceRequest()
        request.bmRequestType = UACRequestCode.setRequestType
        request.bRequest = UACRequestCode.current
        request.wValue = control.wValue
        request.wIndex = control.wIndex
        request.wLength = UInt16(data.count)

        let payload = data.isEmpty ? nil : NSMutableData(bytes: data, length: data.count)
        _ = try send(request, data: payload, label: "SET_CUR")
    }

    /// Single chokepoint for the synchronous control transfer. IOUSBHost exposes
    /// the timeout-bearing variant as `__send` (NS_REFINED_FOR_SWIFT); keep that
    /// `__` name confined here. Returns the number of bytes transferred.
    @discardableResult
    private func send(_ request: IOUSBDeviceRequest, data: NSMutableData?, label: String) throws -> Int {
        var transferred = 0
        do {
            try device.__send(
                request,
                data: data,
                bytesTransferred: &transferred,
                completionTimeout: timeout
            )
        } catch {
            throw AudientError.transferFailed(request: label, underlying: error)
        }
        return transferred
    }
}
