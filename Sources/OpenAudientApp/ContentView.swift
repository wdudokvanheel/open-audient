import SwiftUI
import OpenAudient

struct ContentView: View {
    @EnvironmentObject private var controller: AudientController

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.panelTop, Color.panelBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if controller.isConnected {
                    ScrollView {
                        VStack(spacing: 18) {
                            monitorSection
                            mixerSurface
                            peakMeterSections
                        }
                        .padding(18)
                    }
                } else {
                    statusView
                }
            }
        }
        .foregroundStyle(.primary)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(controller.isConnected ? Color.meterGreen : Color.secondary.opacity(0.55))
                    .shadow(color: controller.isConnected ? Color.meterGreen.opacity(0.65) : .clear, radius: 5)
                    .frame(width: 9, height: 9)

                VStack(alignment: .leading, spacing: 1) {
                    Text(controller.model?.name ?? "Open Audient")
                        .font(.headline.weight(.semibold))
                    Text(controller.isConnected ? "USB mixer online" : "Waiting for interface")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }

            Spacer()

            if controller.isConnected {
                Button { Task { await controller.refresh() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.white.opacity(0.12))
                )
                .help("Re-read values from the device")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.24))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    // MARK: Disconnected / status

    private var statusView: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "hifispeaker.2.fill")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 78, height: 78)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.1))
                )

            Text(statusTitle)
                .font(.title3.weight(.semibold))
            Text(statusDetail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusTitle: String {
        switch controller.connection {
        case .connecting: return "Connecting..."
        case .error: return "Couldn't open the device"
        default: return "No Audient iD connected"
        }
    }

    private var statusDetail: String {
        switch controller.connection {
        case .error(let message): return message
        default: return "Connect an Audient iD interface. Quit the Audient iD app first; it holds exclusive control of the device."
        }
    }

    // MARK: Sections

    private var monitorSection: some View {
        Panel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Monitor")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    LevelReadout(value: controller.mainVolumeDB)
                }

                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading, spacing: 11) {
                        Text("Main Output")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Slider(value: Binding(get: { controller.mainVolumeDB }, set: controller.setMainVolume), in: -60...0)

                        HStack {
                            Text("-60")
                            Spacer()
                            Text("-30")
                            Spacer()
                            Text("0 dB")
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }

                    Divider()
                        .frame(height: 66)
                        .overlay(.white.opacity(0.08))

                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(76), spacing: 8), count: 3), spacing: 8) {
                        ControlPadButton(title: "Cut", systemImage: "speaker.slash.fill", isOn: bind(\.cut, controller.setCut), tint: .red)
                        ControlPadButton(title: "Dim", systemImage: "speaker.wave.1.fill", isOn: bind(\.dim, controller.setDim), tint: .orange)
                        ControlPadButton(title: "Mono", systemImage: "rectangle.split.1x2.fill", isOn: bind(\.mono, controller.setMono), tint: .blue)
                        ControlPadButton(title: "Polarity", systemImage: "plusminus", isOn: bind(\.polarity, controller.setPolarity), tint: .purple)
                        ControlPadButton(title: "Talk", systemImage: "mic.fill", isOn: bind(\.talkback, controller.setTalkback), tint: .mint)
                    }
                }
            }
        }
    }

    private var mixerSurface: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Input to Main Mix")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Text("\(inputChannelCount + dawReturnCount) channels")
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if inputChannelCount + dawReturnCount > 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(0..<inputChannelCount, id: \.self) { index in
                                ChannelStrip(
                                    title: "IN \(index + 1)",
                                    meterIndex: index,
                                    meters: controller.meters,
                                    level: mixerLevel(at: index),
                                    setLevel: { controller.setMixerLevel(input: index, db: $0) }
                                )
                            }
                            ForEach(0..<dawReturnCount, id: \.self) { index in
                                ChannelStrip(
                                    title: dawReturnTitle(at: index),
                                    meterIndex: dawReturnMeterIndex(at: index),
                                    meters: controller.meters,
                                    level: dawReturnLevel(at: index),
                                    setLevel: { controller.setDAWReturnLevel(pair: index, db: $0) }
                                )
                            }
                        }
                        .padding(.bottom, 2)
                    }
                } else {
                    Text("No input channels reported by the connected interface.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 18)
                }
            }
        }
    }

    private var peakMeterSections: some View {
        VStack(spacing: 18) {
            meterPanel(
                title: "Analog Inputs",
                channels: analogMeterChannels
            )
            groupedMeterPanel(
                title: "Digital Inputs",
                channels: digitalMeterChannels,
                stereoTitle: { "DIG \($0 * 2 + 1)+\($0 * 2 + 2)" }
            )
            groupedMeterPanel(
                title: "DAW Playback",
                channels: dawPlaybackMeterChannels,
                stereoTitle: { "DAW \($0 * 2 + 1)+\($0 * 2 + 2)" }
            )
            groupedMeterPanel(
                title: "Hardware Outputs",
                channels: outputMeterChannels,
                stereoTitle: { outputPairTitle(at: $0) }
            )

            if !unmappedMeterChannels.isEmpty {
                meterPanel(
                    title: "Unmapped Peaks",
                    channels: unmappedMeterChannels
                )
            }
        }
    }

    private func meterPanel(title: String, channels: [MeterChannel]) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Text("\(channels.count) channels")
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if channels.isEmpty {
                    Text("No channels reported for this group.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(channels) { channel in
                                MeterStrip(channel: channel, meters: controller.meters)
                            }
                        }
                        .padding(.bottom, 2)
                    }
                }
            }
        }
    }

    private func groupedMeterPanel(
        title: String,
        channels: [MeterChannel],
        stereoTitle: @escaping (Int) -> String
    ) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Text("\(stereoPairs(from: channels, title: stereoTitle).count) pairs")
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 82, alignment: .trailing)
                }

                if channels.isEmpty {
                    Text("No channels reported for this group.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(stereoPairs(from: channels, title: stereoTitle)) { pair in
                                MeterPairStrip(pair: pair, meters: controller.meters)
                            }
                        }
                        .padding(.bottom, 2)
                    }
                }
            }
        }
    }

    private var inputChannelCount: Int {
        max(controller.meters.inputsDB.count, controller.mixerLevelsDB.count)
    }

    private var dawReturnCount: Int {
        max(controller.dawReturnLevelsDB.count, Mixer.dawReturnPairs)
    }

    private var analogMeterChannels: [MeterChannel] {
        guard let model = controller.model else { return [] }
        let available = displayedPeakCount
        let end = min(model.micInputs, available)
        guard end > 0 else { return [] }
        return meterChannels(in: 0..<end) { index in
            "IN \(index + 1)"
        }
    }

    private var digitalMeterChannels: [MeterChannel] {
        guard let model = controller.model else { return [] }
        let start = model.micInputs
        let end = min(model.totalInputs, displayedPeakCount)
        guard start < end else { return [] }
        return meterChannels(in: start..<end) { index in
            "DIG \(index - start + 1)"
        }
    }

    private var dawPlaybackMeterChannels: [MeterChannel] {
        guard let model = controller.model else { return [] }
        let start = min(model.totalInputs, displayedPeakCount)
        guard start < displayedPeakCount else { return [] }
        return meterChannels(in: start..<displayedPeakCount) { index in
            "DAW \(index - start + 1)"
        }
    }

    private var displayedPeakCount: Int {
        max(controller.meters.allDB.count, controller.model?.peakMeterChannels ?? 0)
    }

    private var unmappedMeterChannels: [MeterChannel] {
        guard controller.model == nil else { return [] }
        return meterChannels(in: controller.meters.allDB.indices) { "Peak \($0)" }
    }

    private var outputMeterChannels: [MeterChannel] {
        guard let model = controller.model else { return [] }
        let count = max(controller.meters.outputsDB.count, model.totalOutputs)
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            MeterChannel(index: index, title: outputTitle(at: index), bank: .outputs)
        }
    }

    // MARK: Helpers

    private func bind(_ keyPath: KeyPath<AudientController, Bool>, _ setter: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: { controller[keyPath: keyPath] }, set: setter)
    }

    private func mixerLevel(at index: Int) -> Double {
        guard controller.mixerLevelsDB.indices.contains(index) else { return -60 }
        return controller.mixerLevelsDB[index]
    }

    private func dawReturnLevel(at index: Int) -> Double {
        guard controller.dawReturnLevelsDB.indices.contains(index) else { return -60 }
        return controller.dawReturnLevelsDB[index]
    }

    private func dawReturnTitle(at index: Int) -> String {
        "DAW \(index * 2 + 1)+\(index * 2 + 2)"
    }

    private func dawReturnMeterIndex(at index: Int) -> Int? {
        guard let inputCount = controller.model?.totalInputs else { return nil }
        return inputCount + index * 2
    }

    private func outputTitle(at index: Int) -> String {
        guard let model = controller.model else { return "OUT \(index + 1)" }
        if index < model.lineOutputs {
            return "OUT \(index + 1)"
        }
        return "DIG OUT \(index - model.lineOutputs + 1)"
    }

    private func outputPairTitle(at pair: Int) -> String {
        guard let model = controller.model else { return "OUT \(pair * 2 + 1)+\(pair * 2 + 2)" }
        let left = pair * 2
        let right = left + 1
        if right < model.lineOutputs {
            return "OUT \(left + 1)+\(right + 1)"
        }
        if left >= model.lineOutputs {
            return "DIG OUT \(left - model.lineOutputs + 1)+\(right - model.lineOutputs + 1)"
        }
        return "\(outputTitle(at: left))+\(outputTitle(at: right))"
    }

    private func meterChannels(in range: Range<Int>, title: (Int) -> String) -> [MeterChannel] {
        range.map { MeterChannel(index: $0, title: title($0)) }
    }

    private func stereoPairs(from channels: [MeterChannel], title: (Int) -> String) -> [MeterChannelPair] {
        stride(from: 0, to: channels.count, by: 2).map { offset in
            let left = channels[offset]
            let right = channels.indices.contains(offset + 1) ? channels[offset + 1] : nil
            return MeterChannelPair(id: left.id, title: title(offset / 2), left: left, right: right)
        }
    }
}

private struct Panel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.1), .white.opacity(0.045)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.12))
            )
            .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
    }
}

private struct LevelReadout: View {
    let value: Double

    var body: some View {
        Text(value <= -60 ? "-∞" : String(format: "%.1f dB", value))
            .font(.system(.callout, design: .monospaced).weight(.semibold))
            .foregroundStyle(Color.meterGreen)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.white.opacity(0.08))
            )
    }
}

private struct ControlPadButton: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool
    let tint: Color

    var body: some View {
        Button { isOn.toggle() } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(height: 18)
                Text(title)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isOn ? .black : .primary)
            .frame(width: 76, height: 48)
            .background(isOn ? tint : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isOn ? .white.opacity(0.45) : .white.opacity(0.1))
            )
            .shadow(color: isOn ? tint.opacity(0.35) : .clear, radius: 7)
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private enum MeterBank: Int {
    case inputPlayback
    case outputs
}

private struct MeterChannel: Identifiable {
    let index: Int
    let title: String
    var bank: MeterBank = .inputPlayback

    var id: Int { bank.rawValue * 1000 + index }

    @MainActor
    func dB(from meters: MeterReadings) -> Float {
        let levels = bank == .outputs ? meters.outputsDB : meters.allDB
        guard levels.indices.contains(index) else { return -60 }
        return levels[index]
    }
}

private struct MeterChannelPair: Identifiable {
    let id: Int
    let title: String
    let left: MeterChannel
    let right: MeterChannel?
}

private struct MeterStrip: View {
    let channel: MeterChannel
    @ObservedObject var meters: MeterReadings

    private var dB: Float {
        channel.dB(from: meters)
    }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text(channel.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(String(format: "%02d", channel.index))
                    .font(.caption2.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            .frame(width: 70)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.black.opacity(0.26))

                VerticalMeter(dB: dB)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            .frame(width: 70, height: 236)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(.white.opacity(0.1))
            )
        }
        .padding(10)
        .background(Color.channelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.1))
        )
    }
}

private struct MeterPairStrip: View {
    let pair: MeterChannelPair
    @ObservedObject var meters: MeterReadings
    @State private var isSplit = false

    private var leftDB: Float { pair.left.dB(from: meters) }
    private var rightDB: Float { pair.right?.dB(from: meters) ?? -60 }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 6) {
                VStack(spacing: 2) {
                    Text(pair.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(pair.right.map { String(format: "%02d/%02d", pair.left.index, $0.index) } ?? String(format: "%02d", pair.left.index))
                        .font(.caption2.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                Button(isSplit ? "Mono" : "Stereo") {
                    isSplit.toggle()
                }
                .font(.caption2.weight(.bold))
                .buttonStyle(.plain)
                .foregroundStyle(isSplit ? Color.meterAmber : Color.meterGreen)
                .frame(width: 54, height: 20)
                .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke((isSplit ? Color.meterAmber : Color.meterGreen).opacity(0.45))
                )
                .help("Toggle mono/stereo meter view")
            }
            .frame(width: isSplit ? 150 : 70)

            if isSplit {
                HStack(alignment: .top, spacing: 10) {
                    CompactMeterStrip(channel: pair.left, meters: meters)
                    if let right = pair.right {
                        CompactMeterStrip(channel: right, meters: meters)
                    }
                }
            } else {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.black.opacity(0.26))

                    SplitStereoMeter(leftDB: leftDB, rightDB: rightDB)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                .frame(width: 70, height: 236)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(.white.opacity(0.1))
                )
            }
        }
        .padding(10)
        .background(Color.channelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.1))
        )
    }
}

private struct CompactMeterStrip: View {
    let channel: MeterChannel
    @ObservedObject var meters: MeterReadings

    private var dB: Float {
        channel.dB(from: meters)
    }

    var body: some View {
        VStack(spacing: 7) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.black.opacity(0.26))

                VerticalMeter(dB: dB)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            .frame(width: 62, height: 236)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(.white.opacity(0.1))
            )
        }
    }
}

private struct ChannelStrip: View {
    let title: String
    let meterIndex: Int?
    @ObservedObject var meters: MeterReadings
    let level: Double
    let setLevel: (Double) -> Void

    private var meterDB: Float {
        guard let meterIndex else { return -60 }
        if meters.allDB.indices.contains(meterIndex) {
            return meters.allDB[meterIndex]
        }
        guard meters.inputsDB.indices.contains(meterIndex) else { return -60 }
        return meters.inputsDB[meterIndex]
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.black.opacity(0.26))

                HStack(alignment: .bottom, spacing: 8) {
                    if meterIndex != nil {
                        VerticalMeter(dB: meterDB)
                    }
                    VerticalFader(value: level, setValue: setLevel)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
            .frame(width: 86, height: 236)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(.white.opacity(0.1))
            )

            LevelReadout(value: level)
                .font(.caption)
                .frame(width: 76)
        }
        .padding(10)
        .background(Color.channelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.1))
        )
    }
}

private struct VerticalFader: View {
    let value: Double
    let setValue: (Double) -> Void

    private let minValue: Double = -60
    private let maxValue: Double = 0
    private let trackHeight: CGFloat = 178

    private var fraction: CGFloat {
        CGFloat((clampedValue - minValue) / (maxValue - minValue))
    }

    private var clampedValue: Double {
        min(max(value, minValue), maxValue)
    }

    var body: some View {
        GeometryReader { geo in
            let height = min(trackHeight, geo.size.height)
            let y = (1 - fraction) * height

            ZStack {
                FaderScale(height: height)
                    .frame(width: 34, height: height)

                RoundedRectangle(cornerRadius: 3)
                    .fill(.black.opacity(0.62))
                    .frame(width: 8, height: height)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(.white.opacity(0.08))
                    )
                    .overlay(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [Color.meterGreen.opacity(0.95), Color.meterAmber.opacity(0.8)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(height: max(0, height * fraction))
                            .mask(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 3)
                            }
                    }

                FaderCap()
                    .offset(y: y - (height / 2))
                    .shadow(color: .black.opacity(0.55), radius: 4, y: 2)
            }
            .frame(width: geo.size.width, height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        setValue(value(forY: gesture.location.y, height: height))
                    }
            )
        }
        .frame(width: 34, height: 188)
    }

    private func value(forY y: CGFloat, height: CGFloat) -> Double {
        let normalized = 1 - min(max(y / height, 0), 1)
        return minValue + Double(normalized) * (maxValue - minValue)
    }
}

private struct FaderScale: View {
    let height: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { tick in
                let y = CGFloat(tick) * (height / 6)
                Rectangle()
                    .fill(.white.opacity(tick == 0 || tick == 6 ? 0.28 : 0.18))
                    .frame(width: tick == 0 || tick == 6 ? 24 : 17, height: 1)
                    .offset(y: y - height / 2)
            }
        }
    }
}

private struct FaderCap: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.86, green: 0.88, blue: 0.86),
                        Color(red: 0.48, green: 0.50, blue: 0.50),
                        Color(red: 0.20, green: 0.22, blue: 0.22),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 30, height: 24)
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(.black.opacity(0.45))
                    .frame(width: 24, height: 2)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.white.opacity(0.25))
            )
    }
}

private struct SplitStereoMeter: View {
    let leftDB: Float
    let rightDB: Float

    var body: some View {
        VStack(spacing: 5) {
            SplitStereoMeterBar(leftDB: leftDB, rightDB: rightDB)
                .frame(width: 16, height: 178)

            Text("\(peakText(leftDB))/\(peakText(rightDB))")
                .font(.caption2.monospacedDigit().weight(.medium))
                .foregroundStyle(meterColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 44)
        }
        .animation(.linear(duration: 0.05), value: leftDB)
        .animation(.linear(duration: 0.05), value: rightDB)
    }

    private func peakText(_ dB: Float) -> String {
        dB <= -60 ? "-∞" : String(format: "%.0f", dB)
    }

    private var meterColor: Color {
        max(leftDB, rightDB) > -3 ? Color.meterRed : (max(leftDB, rightDB) > -12 ? Color.meterAmber : Color.meterGreen)
    }
}

private struct SplitStereoMeterBar: View {
    let leftDB: Float
    let rightDB: Float

    private var leftFraction: CGFloat { fraction(leftDB) }
    private var rightFraction: CGFloat { fraction(rightDB) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.black.opacity(0.45))

                HStack(alignment: .bottom, spacing: 1) {
                    meterFill(fraction: leftFraction, height: geo.size.height)
                    meterFill(fraction: rightFraction, height: geo.size.height)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                .mask(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3)
                }

                Rectangle()
                    .fill(.black.opacity(0.45))
                    .frame(width: 1)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(.white.opacity(0.1))
            )
        }
    }

    private func meterFill(fraction: CGFloat, height: CGFloat) -> some View {
        VStack {
            Spacer(minLength: 0)
            LinearGradient(
                colors: [Color.meterGreen, Color.meterGreen, Color.meterAmber, Color.meterRed],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: max(2, height * fraction))
        }
        .frame(maxWidth: .infinity)
    }

    private func fraction(_ dB: Float) -> CGFloat {
        CGFloat(max(0, min(1, (dB + 60) / 60)))
    }
}

private struct VerticalMeter: View {
    let dB: Float

    private var meterColor: Color { dB > -3 ? Color.meterRed : (dB > -12 ? Color.meterAmber : Color.meterGreen) }

    var body: some View {
        VStack(spacing: 5) {
            VerticalMeterBar(dB: dB)
            .frame(width: 16, height: 178)

            Text(dB <= -60 ? "-∞" : String(format: "%.0f", dB))
                .font(.caption2.monospacedDigit().weight(.medium))
                .foregroundStyle(meterColor)
                .frame(width: 28)
        }
        .animation(.linear(duration: 0.05), value: dB)
    }
}

private struct VerticalMeterBar: View {
    let dB: Float

    private var fraction: CGFloat { CGFloat(max(0, min(1, (dB + 60) / 60))) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.black.opacity(0.45))

                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [Color.meterGreen, Color.meterGreen, Color.meterAmber, Color.meterRed],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: max(2, geo.size.height * fraction))
                    .mask(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3)
                    }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(.white.opacity(0.1))
            )
        }
    }
}

private extension Color {
    static let panelTop = Color(red: 0.12, green: 0.13, blue: 0.14)
    static let panelBottom = Color(red: 0.055, green: 0.06, blue: 0.065)
    static let channelSurface = Color(red: 0.10, green: 0.105, blue: 0.11)
    static let meterGreen = Color(red: 0.23, green: 0.92, blue: 0.48)
    static let meterAmber = Color(red: 1.0, green: 0.72, blue: 0.22)
    static let meterRed = Color(red: 1.0, green: 0.22, blue: 0.18)
}
