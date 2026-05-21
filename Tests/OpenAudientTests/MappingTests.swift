import XCTest
@testable import OpenAudient

/// Addressing tests for the mixer, routing and feature-unit controls
/// (cross-referenced with MixiD and verified readable on the iD44).
final class MappingTests: XCTestCase {
    func testMixerLevelAddressing() {
        let c = Mixer.level(channel: 6)
        XCTAssertEqual(c.request.unitID, 0x3C)
        XCTAssertEqual(c.request.selector, 0x01)
        XCTAssertEqual(c.request.channel, 6)
        XCTAssertEqual(c.request.length, 2)
        // 0x8000 little-endian decodes to -128 dB (muted/min).
        XCTAssertEqual(c.decode([0x00, 0x80]), -128.0, accuracy: 0.01)
        // 0xfc67 little-endian -> -3.6 dB, as read from hardware.
        XCTAssertEqual(c.decode([0x67, 0xFC]), -3.6, accuracy: 0.05)
    }

    func testInputChannelStride() {
        XCTAssertEqual(Mixer.inputChannels(0).left, 0)
        XCTAssertEqual(Mixer.inputChannels(0).right, 1)
        XCTAssertEqual(Mixer.inputChannels(2).left, 12)
        XCTAssertEqual(Mixer.inputChannels(2).right, 13)
    }

    func testRoutingAddressing() {
        let c = Routing.source(output: 4)
        XCTAssertEqual(c.request.unitID, 0x33)
        XCTAssertEqual(c.request.wValue, 0x0604, "selector 0x06, channel 4")
        XCTAssertEqual(c.request.length, 1)
    }

    func testHeadphoneFeatureUnitAddressing() {
        XCTAssertEqual(Headphones.leftVolume.request.unitID, 0x0A)
        XCTAssertEqual(Headphones.leftVolume.request.wValue, 0x0203, "VOLUME selector, channel 3")
        XCTAssertEqual(Headphones.rightVolume.request.wValue, 0x0204, "VOLUME selector, channel 4")
        XCTAssertEqual(Headphones.leftMute.request.wValue, 0x0103, "MUTE selector, channel 3")
    }
}
