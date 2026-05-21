import XCTest
@testable import OpenAudient

/// Pure encoding tests — no hardware required. These pin the wire format down
/// to the exact tuples recovered from Audient's own UacLib.
final class UACEncodingTests: XCTestCase {
    func testCutResolvesToKnownTuple() {
        XCTAssertEqual(Monitor.cut.request.unitID, 0x36)
        XCTAssertEqual(Monitor.cut.request.wValue, 0x0400, "selector 4, channel 0")
        XCTAssertEqual(Monitor.cut.request.wIndex, 0x3600, "unit 0x36, interface 0")
        XCTAssertEqual(Monitor.cut.request.length, 1)
    }

    func testMonitorSelectors() {
        XCTAssertEqual(Monitor.mono.request.selector, 0x00)
        XCTAssertEqual(Monitor.polarity.request.selector, 0x03)
        XCTAssertEqual(Monitor.dim.request.selector, 0x05)
        XCTAssertEqual(Monitor.talkback.request.selector, 0x07)
        XCTAssertEqual(Monitor.mainVolume.request.selector, 0x12)
        XCTAssertEqual(Monitor.mainVolume.request.length, 2)
        // Per-output trim carries the output index in the channel byte.
        XCTAssertEqual(Monitor.outputTrim(output: 3).request.wValue, 0x1703)
    }

    func testBoolCodec() {
        XCTAssertEqual(Monitor.cut.encode(true), [0x01])
        XCTAssertEqual(Monitor.cut.encode(false), [0x00])
        XCTAssertTrue(Monitor.cut.decode([0x01]))
        XCTAssertFalse(Monitor.cut.decode([0x00]))
        XCTAssertFalse(Monitor.cut.decode([]), "missing byte decodes as off")
    }

    func testFixedQ88Codec() {
        let v = Monitor.mainVolume
        XCTAssertEqual(v.encode(0.0), [0x00, 0x00])
        XCTAssertEqual(v.encode(1.0), [0x00, 0x01], "1.0 -> 0x0100 LE")
        XCTAssertEqual(v.encode(-1.0), [0x00, 0xFF], "-1.0 -> 0xFF00 LE")
        XCTAssertEqual(v.decode([0x00, 0x01]), 1.0, accuracy: 0.0001)
        XCTAssertEqual(v.decode([0x80, 0xFF]), -0.5, accuracy: 0.0001)
        // Round-trip a fractional value within Q8.8 resolution.
        XCTAssertEqual(v.decode(v.encode(-12.5)), -12.5, accuracy: 1.0 / 256)
    }

    func testWValueWIndexPacking() {
        let request = UACControlRequest(unitID: 0x36, selector: 0x04, channel: 0, length: 1)
        XCTAssertEqual(request.wValue, 0x0400)
        XCTAssertEqual(request.wIndex, 0x3600)

        let channelled = UACControlRequest(unitID: 0x12, selector: 0x02, channel: 0x03, interface: 0x01, length: 2)
        XCTAssertEqual(channelled.wValue, 0x0203)
        XCTAssertEqual(channelled.wIndex, 0x1201)
    }

    func testRequestCodes() {
        XCTAssertEqual(UACRequestCode.setRequestType, 0x21)
        XCTAssertEqual(UACRequestCode.getRequestType, 0xA1)
        XCTAssertEqual(UACRequestCode.current, 0x01)
    }
}
