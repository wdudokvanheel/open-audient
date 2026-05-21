import XCTest
@testable import OpenAudient

/// Pure encoding tests — no hardware required. These pin the wire format down
/// to the exact tuple verified against Audient's own UacLib.
final class UACEncodingTests: XCTestCase {
    func testCutControlResolvesToKnownTuple() {
        let cut = CutControl()
        XCTAssertEqual(cut.request.wValue, 0x0400, "selector 4, channel 0")
        XCTAssertEqual(cut.request.wIndex, 0x3600, "unit 0x36, interface 0")
        XCTAssertEqual(cut.request.length, 1)
    }

    func testCutValueCodec() {
        let cut = CutControl()
        XCTAssertEqual(cut.encode(true), [0x01])
        XCTAssertEqual(cut.encode(false), [0x00])
        XCTAssertTrue(cut.decode([0x01]))
        XCTAssertFalse(cut.decode([0x00]))
        XCTAssertFalse(cut.decode([]), "missing byte decodes as off")
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
