import SwiftUI
import OpenAudient

struct ContentView: View {
    @EnvironmentObject private var controller: AudientController

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if controller.isConnected {
                Form {
                    if !controller.inputMetersDB.isEmpty { metersSection }
                    monitorSection
                    if !controller.mixerLevelsDB.isEmpty { mixerSection }
                }
                .formStyle(.grouped)
            } else {
                statusView
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(controller.isConnected ? Color.green : Color.secondary)
                .frame(width: 9, height: 9)
            Text(controller.model?.name ?? "Open Audient")
                .font(.headline)
            Spacer()
            if controller.isConnected {
                Button { Task { await controller.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Re-read values from the device")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Disconnected / status

    private var statusView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "hifispeaker.2")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(statusTitle).font(.title3)
            Text(statusDetail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusTitle: String {
        switch controller.connection {
        case .connecting: return "Connecting…"
        case .error: return "Couldn’t open the device"
        default: return "No Audient iD connected"
        }
    }

    private var statusDetail: String {
        switch controller.connection {
        case .error(let message): return message
        default: return "Connect an Audient iD interface. Quit the Audient iD app first — it holds exclusive control of the device."
        }
    }

    // MARK: Sections

    private var monitorSection: some View {
        Section("Monitor") {
            Toggle("Cut", isOn: bind(\.cut, controller.setCut))
            Toggle("Dim", isOn: bind(\.dim, controller.setDim))
            Toggle("Mono", isOn: bind(\.mono, controller.setMono))
            Toggle("Polarity", isOn: bind(\.polarity, controller.setPolarity))
            Toggle("Talkback", isOn: bind(\.talkback, controller.setTalkback))
            dBSlider("Speaker level", value: controller.mainVolumeDB, set: controller.setMainVolume)
        }
    }

    private var metersSection: some View {
        Section("Inputs") {
            ForEach(controller.inputMetersDB.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    Text("\(index + 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 16, alignment: .trailing)
                    MeterBar(dB: controller.inputMetersDB[index])
                }
            }
        }
    }

    private var mixerSection: some View {
        Section("Mixer") {
            ForEach(controller.mixerLevelsDB.indices, id: \.self) { index in
                dBSlider("Channel \(index + 1)",
                         value: controller.mixerLevelsDB[index],
                         set: { controller.setMixerLevel(channel: index, db: $0) })
            }
        }
    }

    // MARK: Helpers

    private func bind(_ keyPath: KeyPath<AudientController, Bool>, _ setter: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: { controller[keyPath: keyPath] }, set: setter)
    }

    @ViewBuilder
    private func dBSlider(_ label: String, value: Double, set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                Spacer()
                Text(value <= -60 ? "−∞" : String(format: "%.1f dB", value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { value }, set: set), in: -60...0)
        }
    }
}

/// A horizontal peak-level bar driven by a dBFS value (floor −60).
struct MeterBar: View {
    let dB: Float

    private var fraction: CGFloat { CGFloat(max(0, min(1, (dB + 60) / 60))) }
    private var color: Color { dB > -3 ? .red : (dB > -12 ? .yellow : .green) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule().fill(color).frame(width: max(2, geo.size.width * fraction))
            }
        }
        .frame(height: 8)
        .animation(.linear(duration: 0.05), value: dB)
    }
}
