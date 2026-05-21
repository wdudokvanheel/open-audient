import Foundation
import IOKit

/// Watches the USB bus for Audient iD devices arriving and leaving, via IOKit
/// matched/terminated notifications. Emits an `AsyncStream` of events; the
/// currently-connected devices are reported as `.connected` when the stream
/// starts.
///
///     let monitor = DeviceMonitor()
///     for await event in monitor.events() {
///         switch event { case .connected(let m): … ; case .disconnected(let m): … }
///     }
public final class DeviceMonitor: @unchecked Sendable {
    public enum Event: Sendable, Equatable {
        case connected(DeviceModel)
        case disconnected(DeviceModel)
    }

    private let vendorID: Int
    private let queue = DispatchQueue(label: "com.openaudient.monitor")
    private var port: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private var continuation: AsyncStream<Event>.Continuation?

    public init(vendorID: Int = 0x2708) {
        self.vendorID = vendorID
    }

    /// A stream of connect/disconnect events. Starting it reports any already-
    /// connected devices as `.connected`. Cancelling the consuming task (or
    /// letting the stream terminate) tears the watcher down.
    public func events() -> AsyncStream<Event> {
        AsyncStream { continuation in
            // Strong `self` keeps the monitor alive for the stream's lifetime;
            // the cycle is broken in `stop()` when the stream terminates.
            continuation.onTermination = { _ in self.stop() }
            queue.async { self.start(continuation) }
        }
    }

    private func start(_ continuation: AsyncStream<Event>.Continuation) {
        guard port == nil else { return }
        self.continuation = continuation

        guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
            continuation.finish()
            return
        }
        IONotificationPortSetDispatchQueue(port, queue)
        self.port = port

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        add(kIOFirstMatchNotification, into: &addedIterator, callback: DeviceMonitor.onAdded, port: port, refcon: refcon)
        add(kIOTerminatedNotification, into: &removedIterator, callback: DeviceMonitor.onRemoved, port: port, refcon: refcon)

        // Drain once to arm the notifications and report current state.
        drain(addedIterator, connected: true)
        drain(removedIterator, connected: false)
    }

    private func add(
        _ type: String, into iterator: inout io_iterator_t,
        callback: @escaping IOServiceMatchingCallback,
        port: IONotificationPortRef, refcon: UnsafeMutableRawPointer
    ) {
        // IOUSBHostDevice won't match on idVendor alone, so match the class and
        // filter by vendor when draining.
        let matching = IOServiceMatching("IOUSBHostDevice")
        IOServiceAddMatchingNotification(port, type, matching, callback, refcon, &iterator)
    }

    private static let onAdded: IOServiceMatchingCallback = { refcon, iterator in
        Unmanaged<DeviceMonitor>.fromOpaque(refcon!).takeUnretainedValue().drain(iterator, connected: true)
    }
    private static let onRemoved: IOServiceMatchingCallback = { refcon, iterator in
        Unmanaged<DeviceMonitor>.fromOpaque(refcon!).takeUnretainedValue().drain(iterator, connected: false)
    }

    private func drain(_ iterator: io_iterator_t, connected: Bool) {
        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            if Self.intProperty(service, "idVendor") == vendorID,
               let pid = Self.intProperty(service, "idProduct"),
               let model = DeviceModel.model(forProductID: pid) {
                continuation?.yield(connected ? .connected(model) : .disconnected(model))
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
    }

    private func stop() {
        queue.async {
            if self.addedIterator != IO_OBJECT_NULL { IOObjectRelease(self.addedIterator); self.addedIterator = 0 }
            if self.removedIterator != IO_OBJECT_NULL { IOObjectRelease(self.removedIterator); self.removedIterator = 0 }
            if let port = self.port { IONotificationPortDestroy(port); self.port = nil }
            self.continuation = nil
        }
    }

    static func intProperty(_ service: io_service_t, _ key: String) -> Int? {
        guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)
        else { return nil }
        return (value.takeRetainedValue() as? NSNumber)?.intValue
    }
}
