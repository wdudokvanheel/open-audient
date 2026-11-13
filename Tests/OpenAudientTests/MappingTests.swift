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
        // Hardware sources use 6 slots; main mix is slots 4/5.
        XCTAssertEqual(Mixer.mainSendChannels(input: 0).left, 4)
        XCTAssertEqual(Mixer.mainSendChannels(input: 0).right, 5)
        XCTAssertEqual(Mixer.mainSendChannels(input: 2).left, 16)
        XCTAssertEqual(Mixer.mainSendChannels(input: 2).right, 17)
    }

    func testSendBusChannels() {
        // Each hardware mixer source has cue A, cue B, then main L/R slots.
        XCTAssertEqual(Mixer.sendChannels(source: 0, bus: .cueA)?.left, 0)
        XCTAssertEqual(Mixer.sendChannels(source: 0, bus: .cueA)?.right, 1)
        XCTAssertEqual(Mixer.sendChannels(source: 0, bus: .cueB)?.left, 2)
        XCTAssertEqual(Mixer.sendChannels(source: 0, bus: .cueB)?.right, 3)
        XCTAssertEqual(Mixer.sendChannels(source: 0, bus: .main)?.left, 4)
        XCTAssertEqual(Mixer.sendChannels(source: 0, bus: .main)?.right, 5)
        XCTAssertEqual(Mixer.sendChannels(source: 2, bus: .cueA)?.left, 12)
        XCTAssertEqual(Mixer.sendChannels(source: 2, bus: .cueA)?.right, 13)
        XCTAssertEqual(Mixer.sendChannels(source: 2, bus: .cueB)?.right, 15)
        XCTAssertEqual(Mixer.sendChannels(source: 2, bus: .main)?.right, 17)
        XCTAssertEqual(Mixer.sendChannels(source: 0, bus: .cueC)?.unit, 0x3D)
        XCTAssertEqual(Mixer.sendChannels(source: 0, bus: .cueC)?.left, 0)
        XCTAssertEqual(Mixer.sendChannels(source: 0, bus: .cueC)?.right, 1)
        XCTAssertEqual(Mixer.sendChannels(source: 0, bus: .cueD)?.unit, 0x3D)
        XCTAssertEqual(Mixer.sendChannels(source: 0, bus: .cueD)?.left, 2)
        XCTAssertEqual(Mixer.sendChannels(source: 0, bus: .cueD)?.right, 3)
        XCTAssertEqual(Mixer.sendChannels(source: 2, bus: .cueC)?.left, 8)
        XCTAssertEqual(Mixer.sendChannels(source: 2, bus: .cueD)?.right, 11)
        XCTAssertEqual(Mixer.sendChannels(source: 14, bus: .cueD)?.right, 0x3b)
        XCTAssertNil(Mixer.sendChannels(source: 15, bus: .cueC))
        XCTAssertNil(Mixer.sendChannels(source: 15, bus: .cueD))
    }

    func testDAWReturnChannelsFollowInputs() {
        XCTAssertEqual(Mixer.dawReturnSources(pair: 0, afterInputCount: 20).left, 20)
        XCTAssertEqual(Mixer.dawReturnSources(pair: 0, afterInputCount: 20).right, 21)
        XCTAssertEqual(Mixer.dawReturnChannels(pair: 0, afterInputCount: 20).left.left, 0xa0)
        XCTAssertEqual(Mixer.dawReturnChannels(pair: 0, afterInputCount: 20).left.right, 0xa1)
        XCTAssertEqual(Mixer.dawReturnChannels(pair: 0, afterInputCount: 20).right.left, 0xa8)
        XCTAssertEqual(Mixer.dawReturnChannels(pair: 0, afterInputCount: 20).right.right, 0xa9)
        XCTAssertEqual(Mixer.dawReturnSources(pair: 1, afterInputCount: 20).left, 22)
        XCTAssertEqual(Mixer.dawReturnSources(pair: 1, afterInputCount: 20).right, 23)
    }

    func testDAWMainSendUsesWideMixerStride() {
        XCTAssertEqual(Mixer.dawSendChannels(source: 20, bus: .main)?.left, 0xa0)
        XCTAssertEqual(Mixer.dawSendChannels(source: 20, bus: .main)?.right, 0xa1)
        XCTAssertEqual(Mixer.dawSendChannels(source: 20, bus: .cueA)?.left, 0xa2)
        XCTAssertEqual(Mixer.dawSendChannels(source: 20, bus: .cueA)?.right, 0xa3)
        XCTAssertEqual(Mixer.dawSendChannels(source: 21, bus: .main)?.left, 0xa8)
        XCTAssertEqual(Mixer.dawSendChannels(source: 21, bus: .main)?.right, 0xa9)
        XCTAssertEqual(Mixer.dawSendChannels(source: 21, bus: .cueA)?.left, 0xaa)
        XCTAssertEqual(Mixer.dawSendChannels(source: 21, bus: .cueA)?.right, 0xab)
        XCTAssertNil(Mixer.dawSendChannels(source: 20, bus: .cueC))
        XCTAssertNil(Mixer.dawSendChannels(source: 20, bus: .cueD))
    }

    func testID44PeakChannelsMapToOfficialMixerSources() {
        let model = DeviceModel.iD44
        XCTAssertEqual(model.mixerSource(forAnalogInput: 0), 0)
        XCTAssertEqual(model.mixerSource(forAnalogInput: 1), 1)
        XCTAssertEqual(model.mixerSource(forAnalogInput: 2), 2)
        XCTAssertEqual(model.mixerSource(forAnalogInput: 3), 3)
        XCTAssertEqual(model.mixerSource(forAnalogInput: 2, sendBus: .main), 2)
        XCTAssertEqual(model.mixerSource(forAnalogInput: 2, sendBus: .cueA), 3)
        XCTAssertEqual(model.mixerSource(forAnalogInput: 2, sendBus: .cueB), 3)
        XCTAssertEqual(model.mixerSource(forAnalogInput: 2, sendBus: .cueC), 3)
        XCTAssertEqual(model.mixerSource(forAnalogInput: 2, sendBus: .cueD), 3)
        XCTAssertEqual(model.mixerSource(forAnalogInput: 3, sendBus: .cueA), 4)
        XCTAssertEqual(model.mixerSource(forAnalogInput: 3, sendBus: .cueC), 4)
        XCTAssertEqual(model.mixerSource(forPeakChannel: 0), 0)
        XCTAssertEqual(model.mixerSource(forPeakChannel: 2), 2)
        XCTAssertEqual(model.mixerSource(forPeakChannel: 19), 19)
        XCTAssertEqual(model.mixerSource(forPeakChannel: 20), 20)
        XCTAssertEqual(model.mixerSource(forPeakChannel: 21), 21)
        XCTAssertEqual(model.mixerSource(forPeakChannel: 22), 22)
        XCTAssertEqual(model.mixerSource(forPeakChannel: 23), 23)
        XCTAssertEqual(model.peakChannel(forMixerSource: 0), 0)
        XCTAssertEqual(model.peakChannel(forMixerSource: 2), 2)
        XCTAssertEqual(model.peakChannel(forMixerSource: 20), 20)
    }

    func testRoutingAddressing() {
        let c = Routing.source(output: 4)
        XCTAssertEqual(c.request.unitID, 0x33)
        XCTAssertEqual(c.request.wValue, 0x0604, "selector 0x06, channel 4")
        XCTAssertEqual(c.request.length, 1)
    }

    func testRoutingSourceValues() {
        XCTAssertEqual(Routing.Source.mainMix.value(forOutput: 0), 0x3b)
        XCTAssertEqual(Routing.Source.mainMix.value(forOutput: 1), 0x3c)
        XCTAssertEqual(Routing.Source.mainMix.value(forOutput: 4), 0x3f)
        XCTAssertEqual(Routing.Source.mainMix.value(forOutput: 5), 0x40)
        XCTAssertEqual(Routing.Source.altSpeaker.value(forOutput: 0), 0x3d)
        XCTAssertEqual(Routing.Source.altSpeaker.value(forOutput: 1), 0x3e)
        XCTAssertEqual(Routing.Source.cueA.value(forOutput: 0), 0x2e)
        XCTAssertEqual(Routing.Source.cueA.value(forOutput: 1), 0x2f)
        XCTAssertEqual(Routing.Source.cueB.value(forOutput: 0), 0x30)
        XCTAssertEqual(Routing.Source.cueB.value(forOutput: 1), 0x31)
        XCTAssertEqual(Routing.Source.cueC.value(forOutput: 0), 0x32)
        XCTAssertEqual(Routing.Source.cueC.value(forOutput: 1), 0x33)
        XCTAssertEqual(Routing.Source.cueD.value(forOutput: 0), 0x34)
        XCTAssertEqual(Routing.Source.cueD.value(forOutput: 1), 0x35)
        XCTAssertEqual(Routing.Source.dawThru.value(forOutput: 4), 0x04)
        XCTAssertEqual(
            Routing.Source.matching(leftOutput: 0, leftValue: 0x2e, rightValue: 0x2f),
            .cueA
        )
        XCTAssertEqual(
            Routing.Source.matching(leftOutput: 0, leftValue: 0x34, rightValue: 0x35),
            .cueD
        )
        XCTAssertEqual(
            Routing.Source.matching(leftOutput: 0, leftValue: 0x3b, rightValue: 0x3c),
            .mainMix
        )
        XCTAssertEqual(
            Routing.Source.matching(leftOutput: 4, leftValue: 0x3f, rightValue: 0x40),
            .mainMix
        )
        XCTAssertEqual(
            Routing.Source.matching(leftOutput: 0, leftValue: 0x1b, rightValue: 0x1c),
            .mainMix,
            "Recognize the older MixiD-labelled main values if already present"
        )
        XCTAssertEqual(
            Routing.Source.matching(leftOutput: 0, leftValue: 0x19, rightValue: 0x19),
            .cueA,
            "Recognize the older MixiD-labelled cue values if already present"
        )
        XCTAssertEqual(
            Routing.Source.matching(leftOutput: 4, leftValue: 0x04, rightValue: 0x05),
            .dawThru
        )
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

    func testID44RoutingCoversAllTwentyFourOutputs() {
        // Routing channels 0x00…0x17 answer on hardware: 4 line, 4 HP, 16 ADAT.
        let model = DeviceModel.iD44
        XCTAssertEqual(model.headphoneOutputs, 4)
        XCTAssertEqual(model.totalOutputs, 24)
        XCTAssertEqual(Routing.source(output: UInt8(model.totalOutputs - 1)).request.channel, 0x17)
        // Models without separately routed headphones keep line + digital.
        XCTAssertEqual(DeviceModel.iD22.totalOutputs, 12)
    }

    func testHeadphoneFeatureUnitAddressing() {
        XCTAssertEqual(Headphones.leftVolume.request.unitID, 0x0A)
        XCTAssertEqual(Headphones.leftVolume.request.wValue, 0x0203, "VOLUME selector, channel 3")
        XCTAssertEqual(Headphones.rightVolume.request.wValue, 0x0204, "VOLUME selector, channel 4")
        XCTAssertEqual(Headphones.leftMute.request.wValue, 0x0103, "MUTE selector, channel 3")
    }
}
