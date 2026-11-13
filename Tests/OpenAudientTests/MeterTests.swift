import XCTest
@testable import OpenAudient

/// Meter decoding. Reference values were measured on an iD44 by playing sine
/// tones of known level into DAW playback and reading the peak block.
final class MeterTests: XCTestCase {
    func testFullScalePeakIsZeroDBFS() {
        XCTAssertEqual(Meters.dBFS(0xFFFF), 0, accuracy: 0.001)
    }

    func testMeasuredToneLevels() {
        // -20 dBFS tone: 0.1 × 0xFFFF.
        XCTAssertEqual(Meters.dBFS(0x1999), -20, accuracy: 0.05)
        // -6 dBFS tone: 0.5 × 0xFFFF. Must not read as clipping.
        XCTAssertEqual(Meters.dBFS(0x7FFF), -6.02, accuracy: 0.05)
        // -0.9 dBFS tone: 0.9 × 0xFFFF.
        XCTAssertEqual(Meters.dBFS(0xE666), -0.92, accuracy: 0.05)
    }

    func testSilenceAndFloor() {
        XCTAssertEqual(Meters.dBFS(0), -60)
        XCTAssertEqual(Meters.dBFS(1), -60, "very small peaks clamp to the floor")
        XCTAssertEqual(Meters.dBFS(0, floor: -90), -90)
    }

    func testBusMeterBlockFollowsSendBusOrder() {
        // GET_MEM offset 1 holds L/R pairs for Main, Cue A, Cue B, Cue C, Cue D;
        // the UI labels pair n as Mixer.SendBus(rawValue: n).
        XCTAssertEqual(Meters.busOffset, 1)
        XCTAssertEqual(Meters.busChannels, 10)
        XCTAssertEqual(Mixer.SendBus.allCases, [.main, .cueA, .cueB, .cueC, .cueD])
        XCTAssertEqual(Mixer.SendBus.allCases.map(\.rawValue), [0, 1, 2, 3, 4])
    }

    func testPeaksParseLittleEndianPairs() {
        XCTAssertEqual(Meters.peaks([0x99, 0x19, 0xFF, 0xFF, 0x00]), [0x1999, 0xFFFF])
        XCTAssertEqual(Meters.peaks([0x01]), [])
    }
}
