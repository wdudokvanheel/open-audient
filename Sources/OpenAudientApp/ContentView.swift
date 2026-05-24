import SwiftUI
import OpenAudient

struct ContentView: View {
    @EnvironmentObject private var controller: AudientController

    var body: some View {
        ZStack {
            Color.appBase
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.appTop, Color.appBase, Color.appBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if controller.isConnected {
                    ScrollView {
                        VStack(spacing: 18) {
                            monitorSection
                            outputRoutingSection
                            peakMeterSections
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                        .frame(maxWidth: 1180, alignment: .topLeading)
                        .frame(maxWidth: .infinity)
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
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            LinearGradient(
                                colors: [Color.audientRed.opacity(0.95), Color.audientRed.opacity(0.42)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "slider.vertical.3")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .frame(width: 34, height: 34)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(.white.opacity(0.16))
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(controller.model?.name ?? "Open Audient")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(controller.isConnected ? Color.meterGreen : Color.secondary.opacity(0.55))
                            .shadow(color: controller.isConnected ? Color.meterGreen.opacity(0.6) : .clear, radius: 4)
                            .frame(width: 6, height: 6)
                        Text(controller.isConnected ? "USB mixer online" : "Waiting for interface")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }
                }
            }

            Spacer()

            if controller.isConnected {
                Button { Task { await controller.refresh() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(Color.controlSurface, in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.white.opacity(0.14))
                )
                .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
                .help("Re-read values from the device")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.headerTop, Color.headerBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.09))
                .frame(height: 1)
        }
    }

    // MARK: Disconnected / status

    private var statusView: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "hifispeaker.2.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 82, height: 82)
                .background(Color.channelSurface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.12))
                )
                .shadow(color: .black.opacity(0.28), radius: 16, y: 8)

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
                SectionHeader(
                    title: "Monitor",
                    detail: controller.isConnected ? "Main output control" : nil,
                    count: nil
                )

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 16) {
                        monitorSlider
                        Spacer(minLength: 0)
                        monitorButtons
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        monitorSlider
                        monitorButtons
                    }
                }
            }
        }
    }

    private var monitorSlider: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Main Output")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                LevelReadout(value: controller.mainVolumeDB)
            }

            Slider(value: Binding(get: { controller.mainVolumeDB }, set: controller.setMainVolume), in: -60...0)
                .tint(Color.audientRed)

            HStack {
                Text("-60")
                Spacer()
                Text("-30")
                Spacer()
                Text("0 dB")
            }
            .font(.caption2.monospacedDigit().weight(.medium))
            .foregroundStyle(.secondary.opacity(0.85))
        }
        .padding(14)
        .frame(minWidth: 260)
        .background(Color.controlSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.1))
        )
    }

    private var monitorButtons: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(76), spacing: 8), count: 3), spacing: 8) {
            ControlPadButton(title: "Cut", systemImage: "speaker.slash.fill", isOn: bind(\.cut, controller.setCut), tint: .red)
            ControlPadButton(title: "Dim", systemImage: "speaker.wave.1.fill", isOn: bind(\.dim, controller.setDim), tint: .orange)
            ControlPadButton(title: "Mono", systemImage: "rectangle.split.1x2.fill", isOn: bind(\.mono, controller.setMono), tint: .blue)
            ControlPadButton(title: "Polarity", systemImage: "plusminus", isOn: bind(\.polarity, controller.setPolarity), tint: .purple)
            ControlPadButton(title: "Talk", systemImage: "mic.fill", isOn: bind(\.talkback, controller.setTalkback), tint: .mint)
        }
    }

    private var outputRoutingSection: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Output Routing",
                    detail: "Assign each stereo output pair",
                    count: "\(outputRoutingPairs.count) pairs"
                )

                if outputRoutingPairs.isEmpty {
                    EmptyMeterState()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("Output")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 94, alignment: .leading)

                                ForEach(Routing.Source.allCases) { source in
                                    Text(source.title)
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.72)
                                        .frame(width: 66, height: 30)
                                }
                            }

                            ForEach(outputRoutingPairs) { pair in
                                OutputRoutingRow(pair: pair)
                                    .environmentObject(controller)
                            }
                        }
                        .padding(.bottom, 2)
                    }
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
                title: "DAW Input",
                channels: dawPlaybackMeterChannels,
                stereoTitle: { "DAW \($0 * 2 + 1)+\($0 * 2 + 2)" }
            )
            groupedMeterPanel(
                title: "Internal Peaks",
                channels: internalPeakChannels,
                stereoTitle: internalPeakPairTitle
            )
            groupedMeterPanel(
                title: "Hardware Outputs",
                channels: outputMeterChannels,
                stereoTitle: hardwareOutputPairTitle
            )
            groupedMeterPanel(
                title: "Cues",
                channels: cueMeterChannels,
                stereoTitle: cuePairTitle
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
                SectionHeader(title: title, detail: nil, count: "\(channels.count) channels")

                if channels.isEmpty {
                    EmptyMeterState()
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
                SectionHeader(
                    title: title,
                    detail: nil,
                    count: "\(stereoPairs(from: channels, title: stereoTitle).count) pairs"
                )

                if channels.isEmpty {
                    EmptyMeterState()
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

    private var analogMeterChannels: [MeterChannel] {
        guard let model = controller.model else { return [] }
        let available = displayedPeakCount
        let end = min(model.micInputs, available)
        guard end > 0 else { return [] }
        return meterChannels(in: 0..<end, controlled: controller.isControllableMainMixSource) { index in
            "IN \(index + 1)"
        }
    }

    private var digitalMeterChannels: [MeterChannel] {
        guard let model = controller.model else { return [] }
        let start = model.micInputs
        let end = min(model.totalInputs, displayedPeakCount)
        guard start < end else { return [] }
        return meterChannels(in: start..<end, controlled: controller.isControllableMainMixSource) { index in
            "DIG \(index - start + 1)"
        }
    }

    private var dawPlaybackMeterChannels: [MeterChannel] {
        guard let model = controller.model else { return [] }
        let start = min(model.totalInputs, displayedPeakCount)
        let end = min(start + displayedDAWPlaybackChannels, displayedPeakCount)
        guard start < end else { return [] }
        return meterChannels(in: start..<end, controlled: controller.isControllableMainMixSource) { index in
            "DAW \(index - start + 1)"
        }
    }

    private var internalPeakChannels: [MeterChannel] {
        guard let model = controller.model else { return [] }
        let start = internalPeakStart(for: model)
        guard start < displayedPeakCount else { return [] }
        return meterChannels(in: start..<displayedPeakCount) { index in "PEAK \(index + 1)" }
    }

    private var displayedDAWPlaybackChannels: Int { 4 }

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
        return (0..<count).filter { !isCueOutput(index: $0, model: model) }.map { index in
            MeterChannel(index: index, title: outputTitle(at: index), bank: .outputs)
        }
    }

    private var cueMeterChannels: [MeterChannel] {
        guard let model = controller.model else { return [] }
        let count = max(controller.meters.outputsDB.count, model.totalOutputs)
        guard count > 0 else { return [] }
        return (0..<count).filter { isCueOutput(index: $0, model: model) }.map { index in
            MeterChannel(index: index, title: outputTitle(at: index), bank: .outputs)
        }
    }

    private var outputRoutingPairs: [OutputRoutingPair] {
        guard let model = controller.model else { return [] }
        let count = model.totalOutputs
        guard count > 0 else { return [] }
        return stride(from: 0, to: count, by: 2).map { left in
            OutputRoutingPair(id: left, leftOutput: left, title: physicalOutputPairTitle(leftIndex: left, model: model))
        }
    }

    // MARK: Helpers

    private func bind(_ keyPath: KeyPath<AudientController, Bool>, _ setter: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: { controller[keyPath: keyPath] }, set: setter)
    }

    private func outputTitle(at index: Int) -> String {
        guard let model = controller.model else { return "OUT \(index + 1)" }
        if let cueTitle = cueOutputTitle(at: index, model: model) {
            return cueTitle
        }
        return physicalOutputTitle(at: index, model: model)
    }

    private func physicalOutputPairTitle(leftIndex left: Int, model: DeviceModel) -> String {
        let right = left + 1
        if let headphones = headphonePairName(leftIndex: left, model: model) {
            return headphones
        }
        if right < model.lineOutputs {
            return "OUT \(left + 1)+\(right + 1)"
        }
        if left >= model.lineOutputs {
            let first = digitalOutputNumber(forOutput: left, model: model)
            return "DIG OUT \(first)+\(first + 1)"
        }
        return "\(physicalOutputTitle(at: left, model: model))+\(physicalOutputTitle(at: right, model: model))"
    }

    private func physicalOutputTitle(at index: Int, model: DeviceModel) -> String {
        if let headphones = headphoneOutputTitle(at: index, model: model) {
            return headphones
        }
        if index < model.lineOutputs {
            return "OUT \(index + 1)"
        }
        return "DIG OUT \(digitalOutputNumber(forOutput: index, model: model))"
    }

    private func hardwareOutputPairTitle(at pair: Int) -> String {
        let channels = outputMeterChannels
        let offset = pair * 2
        guard channels.indices.contains(offset) else { return "OUT \(pair * 2 + 1)+\(pair * 2 + 2)" }
        let left = channels[offset].index
        let right = channels.indices.contains(offset + 1) ? channels[offset + 1].index : left + 1
        return outputPairTitle(leftIndex: left, rightIndex: right)
    }

    private func cuePairTitle(at pair: Int) -> String {
        let channels = cueMeterChannels
        let offset = pair * 2
        guard channels.indices.contains(offset) else { return "CUE \(pair + 1)" }
        let left = channels[offset].index
        guard let model = controller.model else { return outputPairTitle(leftIndex: left, rightIndex: left + 1) }
        return cueOutputPairTitle(leftIndex: left, model: model) ?? outputPairTitle(leftIndex: left, rightIndex: left + 1)
    }

    private func outputPairTitle(leftIndex left: Int, rightIndex right: Int) -> String {
        guard let model = controller.model else { return "OUT \(left + 1)+\(right + 1)" }
        if let cueTitle = cueOutputPairTitle(leftIndex: left, model: model) {
            return cueTitle
        }
        if right < model.lineOutputs {
            return "OUT \(left + 1)+\(right + 1)"
        }
        if left >= model.lineOutputs {
            let first = digitalOutputNumber(forOutput: left, model: model)
            return "DIG OUT \(first)+\(first + 1)"
        }
        return "\(outputTitle(at: left))+\(outputTitle(at: right))"
    }

    private func isCueOutput(index: Int, model: DeviceModel) -> Bool {
        cueOutputName(leftIndex: index - index % 2, model: model) != nil
    }

    private func cueOutputTitle(at index: Int, model: DeviceModel) -> String? {
        guard let cue = cueOutputName(leftIndex: index - index % 2, model: model) else { return nil }
        return "\(cue) \(index.isMultiple(of: 2) ? "L" : "R")"
    }

    private func cueOutputPairTitle(leftIndex: Int, model: DeviceModel) -> String? {
        cueOutputName(leftIndex: leftIndex, model: model)
    }

    private func cueOutputName(leftIndex: Int, model: DeviceModel) -> String? {
        switch leftIndex {
        case 2 where model.lineOutputs >= 4:
            return "CUE A"
        case model.lineOutputs:
            return "CUE B"
        case model.lineOutputs + 2:
            return "CUE C"
        case model.lineOutputs + 4:
            return "CUE D"
        default:
            return nil
        }
    }

    private func headphonePairName(leftIndex: Int, model: DeviceModel) -> String? {
        guard hasDedicatedHeadphoneOutputLabels(model) else { return nil }
        switch leftIndex {
        case model.lineOutputs:
            return "HP 1"
        case model.lineOutputs + 2:
            return "HP 2"
        default:
            return nil
        }
    }

    private func headphoneOutputTitle(at index: Int, model: DeviceModel) -> String? {
        guard hasDedicatedHeadphoneOutputLabels(model) else { return nil }
        let left = index - index % 2
        guard let pairName = headphonePairName(leftIndex: left, model: model) else { return nil }
        return "\(pairName) \(index.isMultiple(of: 2) ? "L" : "R")"
    }

    private func digitalOutputNumber(forOutput index: Int, model: DeviceModel) -> Int {
        index - model.lineOutputs - headphoneOutputChannels(for: model) + 1
    }

    private func headphoneOutputChannels(for model: DeviceModel) -> Int {
        hasDedicatedHeadphoneOutputLabels(model) ? 4 : 0
    }

    private func hasDedicatedHeadphoneOutputLabels(_ model: DeviceModel) -> Bool {
        model.productID == DeviceModel.iD44.productID || model.productID == DeviceModel.iD44mkII.productID
    }

    private func internalPeakStart(for model: DeviceModel) -> Int {
        min(model.totalInputs + displayedDAWPlaybackChannels, displayedPeakCount)
    }

    private func internalPeakPairTitle(at pair: Int) -> String {
        guard let model = controller.model else { return "PEAK \(pair * 2 + 1)+\(pair * 2 + 2)" }
        let left = internalPeakStart(for: model) + pair * 2
        let right = left + 1
        return "PEAK \(left + 1)+\(right + 1)"
    }

    private func meterChannels(in range: Range<Int>, controlled: (Int) -> Bool = { _ in false }, title: (Int) -> String) -> [MeterChannel] {
        range.map { MeterChannel(index: $0, title: title($0), controlSource: controlled($0) ? $0 : nil) }
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
                            colors: [Color.panelSurfaceTop, Color.panelSurfaceBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.18))
                    .offset(y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.panelStroke)
            )
            .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
    }
}

private struct SectionHeader: View {
    let title: String
    let detail: String?
    let count: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let detail {
                    Text(detail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let count {
                Text(count)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(.white.opacity(0.08))
                    )
            }
        }
    }
}

private struct EmptyMeterState: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No channels reported for this group.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
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
            .background(Color.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 5))
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
            .foregroundStyle(isOn ? .white : .primary.opacity(0.92))
            .frame(width: 76, height: 48)
            .background(
                LinearGradient(
                    colors: isOn
                        ? [tint.opacity(0.95), tint.opacity(0.56)]
                        : [Color.white.opacity(0.09), Color.white.opacity(0.045)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isOn ? .white.opacity(0.34) : .white.opacity(0.11))
            )
            .shadow(color: isOn ? tint.opacity(0.28) : .black.opacity(0.16), radius: isOn ? 8 : 4, y: 2)
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private enum MeterBank: Int {
    case inputPlayback
    case outputs
}

private struct OutputRoutingPair: Identifiable {
    let id: Int
    let leftOutput: Int
    let title: String
}

private struct OutputRoutingRow: View {
    @EnvironmentObject private var controller: AudientController

    let pair: OutputRoutingPair

    private var selectedSource: Routing.Source? {
        controller.outputRouteSource(forPairStartingAt: pair.leftOutput)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(pair.title)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: 94, height: 28, alignment: .leading)
                .padding(.horizontal, 8)
                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.white.opacity(0.08))
                )

            ForEach(Routing.Source.allCases) { source in
                RoutingSourceButton(isSelected: selectedSource == source) {
                    controller.setOutputRoute(pairStartingAt: pair.leftOutput, source: source)
                }
            }
        }
    }
}

private struct RoutingSourceButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [Color.white.opacity(0.96), Color.white.opacity(0.55)]
                                : [Color.black.opacity(0.58), Color.black.opacity(0.34)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 15, height: 15)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.white.opacity(0.75) : Color.white.opacity(0.13), lineWidth: 1)
                    )
                    .shadow(color: isSelected ? Color.white.opacity(0.28) : .black.opacity(0.28), radius: isSelected ? 5 : 2)

                if isSelected {
                    Circle()
                        .fill(Color.appBase)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 66, height: 28)
            .background(isSelected ? Color.white.opacity(0.045) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }
}

private struct MeterChannel: Identifiable {
    let index: Int
    let title: String
    var bank: MeterBank = .inputPlayback
    var controlSource: Int? = nil

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
        MixerMeterModule(
            title: channel.title,
            subtitle: nil,
            leftDB: dB,
            controlSource: channel.controlSource
        )
        .padding(10)
        .background(
            LinearGradient(
                colors: [Color.channelSurfaceTop, Color.channelSurface],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
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
    private var hasControls: Bool { pair.left.controlSource != nil || pair.right?.controlSource != nil }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 6) {
                VStack(spacing: 2) {
                    Text(pair.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Button(isSplit ? "Mono" : "Stereo") {
                    isSplit.toggle()
                }
                .font(.caption2.weight(.bold))
                .buttonStyle(.plain)
                .foregroundStyle(isSplit ? Color.meterAmber : Color.meterGreen)
                .frame(width: 54, height: 20)
                .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke((isSplit ? Color.meterAmber : Color.meterGreen).opacity(0.5))
                )
                .help("Toggle mono/stereo meter view")
            }
            .frame(width: isSplit ? 150 : 70)
            .padding(.horizontal, 10)
            .padding(.top, 10)

            if isSplit {
                HStack(alignment: .top, spacing: 10) {
                    CompactMeterStrip(channel: pair.left, meters: meters)
                    if let right = pair.right {
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 1, height: 236)
                        CompactMeterStrip(channel: right, meters: meters)
                    }
                }
                .padding(.horizontal, hasControls ? 0 : 10)
                .padding(.bottom, hasControls ? 0 : 10)
            } else {
                MixerMeterModule(
                    title: nil,
                    subtitle: nil,
                    leftDB: leftDB,
                    rightDB: rightDB,
                    controlSource: pair.left.controlSource,
                    pairedControlSource: pair.right?.controlSource
                )
                .padding(.horizontal, hasControls ? 0 : 10)
                .padding(.bottom, hasControls ? 0 : 10)
            }
        }
        .background(
            LinearGradient(
                colors: [Color.channelSurfaceTop, Color.channelSurface],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
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
        MixerMeterModule(
            title: nil,
            subtitle: nil,
            leftDB: dB,
            controlSource: channel.controlSource,
            width: 62
        )
    }
}

private struct MixerMeterModule: View {
    @EnvironmentObject private var controller: AudientController

    let title: String?
    let subtitle: String?
    let leftDB: Float
    var rightDB: Float? = nil
    var controlSource: Int? = nil
    var pairedControlSource: Int? = nil
    var width: CGFloat = 70

    private var controlSources: [Int] {
        [controlSource, pairedControlSource].compactMap { $0 }
    }

    private var level: Double {
        guard let source = controlSource,
              controller.mainMixSourceLevelsDB.indices.contains(source) else { return -60 }
        return controller.mainMixSourceLevelsDB[source]
    }

    private var isMuted: Bool {
        !controlSources.isEmpty && controlSources.allSatisfy { controller.mutedMainMixSources.contains($0) }
    }

    private var isSoloed: Bool {
        !controlSources.isEmpty && controlSources.allSatisfy { controller.soloedMainMixSources.contains($0) }
    }

    var body: some View { content }

    private var content: some View {
        VStack(spacing: 10) {
            if title != nil || subtitle != nil {
                VStack(spacing: 2) {
                    if let title {
                        Text(title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2.monospacedDigit().weight(.medium))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                }
                .frame(width: width)
            }

            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 8) {
                    if let rightDB {
                        SplitStereoMeter(leftDB: leftDB, rightDB: rightDB)
                    } else {
                        VerticalMeter(dB: leftDB)
                    }

                    if controlSource != nil {
                        VerticalFader(value: level, setValue: setLevel)
                    }
                }
                .padding(.horizontal, controlSource == nil ? 14 : 10)
                .padding(.top, controlSource == nil ? 12 : 18)
                .padding(.bottom, 12)
                .frame(height: controlSource == nil ? 236 : 198)

                if controlSource != nil {
                    HStack(spacing: 0) {
                        MeterActionButton(title: "M", isOn: isMuted, tint: .meterAmber, side: .left) {
                            setMuted(!isMuted)
                        }
                        MeterActionButton(title: "S", isOn: isSoloed, tint: .meterGreen, side: .right) {
                            setSoloed(!isSoloed)
                        }
                    }
                    .frame(height: 32)
                    .padding(.top, 6)
                }
            }
            .frame(width: controlSource == nil ? width : width + 42, height: 236)
        }
    }

    private func setLevel(_ db: Double) {
        if let pairedControlSource {
            controller.setMainMixStereoPairLevel(pairStartingAt: controlSource ?? pairedControlSource, db: db)
        } else if let controlSource {
            controller.setMainMixSourceLevel(source: controlSource, db: db)
        }
    }

    private func setMuted(_ muted: Bool) {
        for source in controlSources {
            controller.setMainMixSourceMuted(source: source, muted: muted)
        }
    }

    private func setSoloed(_ soloed: Bool) {
        for source in controlSources {
            controller.setMainMixSourceSoloed(source: source, soloed: soloed)
        }
    }
}

private struct MeterActionButton: View {
    enum Side {
        case left
        case right
    }

    let title: String
    let isOn: Bool
    let tint: Color
    let side: Side
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(tint.opacity(isOn ? 1.0 : 0.85))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    isOn ? tint.opacity(0.18) : Color.white.opacity(0.075),
                    in: BottomOuterCornerShape(side: side, radius: 8)
                )
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(isOn ? tint.opacity(0.28) : Color.white.opacity(0.1))
                        .frame(height: 1)
                }
                .overlay(alignment: side == .left ? .trailing : .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }
}

private struct BottomOuterCornerShape: Shape {
    let side: MeterActionButton.Side
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width / 2, rect.height / 2)
        var path = Path()

        switch side {
        case .left:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - r),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        case .right:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }

        path.closeSubpath()
        return path
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
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .overlay(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [Color.meterGreen.opacity(0.95), Color.audientRed.opacity(0.72)],
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
                        Color(red: 0.94, green: 0.95, blue: 0.93),
                        Color(red: 0.56, green: 0.58, blue: 0.58),
                        Color(red: 0.23, green: 0.245, blue: 0.25),
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
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.68), Color.black.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                HStack(alignment: .bottom, spacing: 1) {
                    meterFill(fraction: leftFraction, height: geo.size.height)
                    meterFill(fraction: rightFraction, height: geo.size.height)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
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

    private func meterFill(fraction: CGFloat, height: CGFloat) -> some View {
        VStack {
            Spacer(minLength: 0)
            LinearGradient(
                colors: [Color.meterGreen, Color.meterGreen, Color.meterAmber, Color.meterRed],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: max(2, height * fraction))
            .shadow(color: Color.meterGreen.opacity(0.18), radius: 3)
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
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.68), Color.black.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [Color.meterGreen, Color.meterGreen, Color.meterAmber, Color.meterRed],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: max(2, geo.size.height * fraction))
                    .shadow(color: Color.meterGreen.opacity(0.18), radius: 3)
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
    static let appTop = Color(red: 0.16, green: 0.17, blue: 0.18)
    static let appBase = Color(red: 0.085, green: 0.09, blue: 0.095)
    static let appBottom = Color(red: 0.045, green: 0.05, blue: 0.055)
    static let headerTop = Color(red: 0.145, green: 0.15, blue: 0.16)
    static let headerBottom = Color(red: 0.075, green: 0.08, blue: 0.088)
    static let panelSurfaceTop = Color(red: 0.155, green: 0.162, blue: 0.17)
    static let panelSurfaceBottom = Color(red: 0.098, green: 0.103, blue: 0.11)
    static let panelStroke = Color.white.opacity(0.115)
    static let controlSurface = Color(red: 0.105, green: 0.11, blue: 0.118)
    static let audientRed = Color(red: 0.88, green: 0.16, blue: 0.13)
    static let channelSurface = Color(red: 0.10, green: 0.105, blue: 0.11)
    static let channelSurfaceTop = Color(red: 0.135, green: 0.14, blue: 0.148)
    static let meterGreen = Color(red: 0.23, green: 0.92, blue: 0.48)
    static let meterAmber = Color(red: 1.0, green: 0.72, blue: 0.22)
    static let meterRed = Color(red: 1.0, green: 0.22, blue: 0.18)
}
