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

    func testMainSendChannels() {
        // Each input has 6 slots; main mix is slots 4/5 (confirmed on hardware).
        XCTAssertEqual(Mixer.mainSendChannels(input: 0).left, 4)
        XCTAssertEqual(Mixer.mainSendChannels(input: 0).right, 5)
        XCTAssertEqual(Mixer.mainSendChannels(input: 2).left, 16)
        XCTAssertEqual(Mixer.mainSendChannels(input: 2).right, 17)
    }

    func testDAWReturnChannelsFollowInputs() {
        // On the iD44 there are 20 hardware input sources, followed by DAW 1+2
        // and DAW 3+4 return pairs in the same 6-slot mixer source map.
        XCTAssertEqual(Mixer.dawReturnSources(pair: 0, afterInputCount: 20).left, 20)
        XCTAssertEqual(Mixer.dawReturnSources(pair: 0, afterInputCount: 20).right, 21)
        XCTAssertEqual(Mixer.dawReturnChannels(pair: 0, afterInputCount: 20).left.left, 124)
        XCTAssertEqual(Mixer.dawReturnChannels(pair: 0, afterInputCount: 20).left.right, 125)
        XCTAssertEqual(Mixer.dawReturnChannels(pair: 0, afterInputCount: 20).right.left, 130)
        XCTAssertEqual(Mixer.dawReturnChannels(pair: 0, afterInputCount: 20).right.right, 131)
        XCTAssertEqual(Mixer.dawReturnSources(pair: 1, afterInputCount: 20).left, 22)
        XCTAssertEqual(Mixer.dawReturnSources(pair: 1, afterInputCount: 20).right, 23)
    }

    func testRoutingAddressing() {
        let c = Routing.source(output: 4)
        XCTAssertEqual(c.request.unitID, 0x33)
        XCTAssertEqual(c.request.wValue, 0x0604, "selector 0x06, channel 4")
        XCTAssertEqual(c.request.length, 1)
    }

    func testPreampAddressing() {
        // Phase selector 0x0d on feature unit 0x0b, channel = input (confirmed).
        let phase = Preamp.phase(input: 2)
        XCTAssertEqual(phase.request.unitID, 0x0B)
        XCTAssertEqual(phase.request.wValue, 0x0D02, "phase selector 0x0d, channel 2")
        XCTAssertEqual(phase.request.length, 1)

        let gain = Preamp.gain(input: 1)
        XCTAssertEqual(gain.request.wValue, 0x0B01, "gain selector 0x0b, channel 1")
        XCTAssertEqual(gain.request.length, 2)
        XCTAssertEqual(gain.encode(0.0), [0x00, 0x00])

        XCTAssertEqual(Preamp.pad(input: 3).request.wValue, 0x0C03, "pad selector 0x0c, channel 3")
    }

    func testHeadphoneFeatureUnitAddressing() {
        XCTAssertEqual(Headphones.leftVolume.request.unitID, 0x0A)
        XCTAssertEqual(Headphones.leftVolume.request.wValue, 0x0203, "VOLUME selector, channel 3")
        XCTAssertEqual(Headphones.rightVolume.request.wValue, 0x0204, "VOLUME selector, channel 4")
        XCTAssertEqual(Headphones.leftMute.request.wValue, 0x0103, "MUTE selector, channel 3")
    }
}
