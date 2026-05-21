import XCTest
@testable import OpenAudient

/// An in-memory transport that records traffic, so `AudientDevice` logic can be
/// exercised without hardware.
final class MockTransport: USBControlTransport {
    var stored: [UInt8] = [0x00]
    private(set) var setCalls: [(request: UACControlRequest, data: [UInt8])] = []
    private(set) var getCalls: [UACControlRequest] = []

    func getCurrent(_ request: UACControlRequest) throws -> [UInt8] {
        getCalls.append(request)
        return stored
    }

    func setCurrent(_ request: UACControlRequest, data: [UInt8]) throws {
        setCalls.append((request, data))
        stored = data
    }
}

final class AudientDeviceTests: XCTestCase {
    func testReadDecodesStoredBytes() throws {
        let mock = MockTransport()
        mock.stored = [0x01]
        let device = AudientDevice(transport: mock)

        XCTAssertTrue(try device.read(Monitor.cut))
        XCTAssertEqual(mock.getCalls.first?.wIndex, 0x3600)
    }

    func testWriteSendsEncodedBytesToCorrectAddress() throws {
        let mock = MockTransport()
        let device = AudientDevice(transport: mock)

        try device.write(Monitor.cut, true)

        XCTAssertEqual(mock.setCalls.count, 1)
        XCTAssertEqual(mock.setCalls.first?.data, [0x01])
        XCTAssertEqual(mock.setCalls.first?.request.wValue, 0x0400)
        XCTAssertEqual(mock.setCalls.first?.request.wIndex, 0x3600)
    }

    func testToggleReadsThenWritesInverse() throws {
        let mock = MockTransport()
        mock.stored = [0x00]
        let device = AudientDevice(transport: mock)

        let result = try device.toggle(Monitor.cut)

        XCTAssertTrue(result)
        XCTAssertEqual(mock.stored, [0x01])
        XCTAssertEqual(mock.getCalls.count, 1)
        XCTAssertEqual(mock.setCalls.count, 1)
    }
}
