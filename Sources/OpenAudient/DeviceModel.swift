/// A model in the Audient iD family, with its I/O topology.
///
/// Counts come from the published iD range (cross-referenced with the MixiD
/// project's device table). Only the iD44 is hardware-verified by this project;
/// the others are modelled so the library and UI can adapt, but their protocol
/// details should be confirmed before relying on them.
public struct DeviceModel: Sendable, Equatable, Identifiable {
    public let name: String
    public let productID: Int
    /// Mic/line preamp inputs.
    public let micInputs: Int
    /// Digital (ADAT/SPDIF) inputs.
    public let digitalInputs: Int
    /// Analogue line outputs.
    public let lineOutputs: Int
    /// Digital outputs.
    public let digitalOutputs: Int
    /// Insert points.
    public let inserts: Int
    /// Whether this project has verified control of the device on real hardware.
    public let isVerified: Bool

    public var id: Int { productID }
    public var identifier: USBIdentifier { USBIdentifier(vendorID: 0x2708, productID: productID) }
    public var totalInputs: Int { micInputs + digitalInputs }
    public var totalOutputs: Int { lineOutputs + digitalOutputs }
    /// Peak meter slots exposed by the mixer memory block: hardware inputs
    /// followed by DAW playback channels.
    public var peakMeterChannels: Int { totalInputs + dawPlaybackChannels }
    /// DAW playback channels presented to the hardware mixer.
    public var dawPlaybackChannels: Int {
        switch productID {
        case DeviceModel.iD44.productID, DeviceModel.iD44mkII.productID:
            return 24
        default:
            return totalOutputs
        }
    }

    public init(
        name: String, productID: Int,
        micInputs: Int, digitalInputs: Int,
        lineOutputs: Int, digitalOutputs: Int,
        inserts: Int = 0, isVerified: Bool = false
    ) {
        self.name = name
        self.productID = productID
        self.micInputs = micInputs
        self.digitalInputs = digitalInputs
        self.lineOutputs = lineOutputs
        self.digitalOutputs = digitalOutputs
        self.inserts = inserts
        self.isVerified = isVerified
    }
}

extension DeviceModel {
    public static let iD4     = DeviceModel(name: "iD4",       productID: 0x0003, micInputs: 1, digitalInputs: 0,  lineOutputs: 2, digitalOutputs: 0)
    public static let iD4mkII = DeviceModel(name: "iD4 MkII",  productID: 0x0009, micInputs: 1, digitalInputs: 0,  lineOutputs: 2, digitalOutputs: 0)
    public static let iD14    = DeviceModel(name: "iD14",      productID: 0x0002, micInputs: 2, digitalInputs: 8,  lineOutputs: 4, digitalOutputs: 0)
    public static let iD14mkII = DeviceModel(name: "iD14 MkII", productID: 0x0008, micInputs: 2, digitalInputs: 8, lineOutputs: 4, digitalOutputs: 0)
    public static let iD22    = DeviceModel(name: "iD22",      productID: 0x0001, micInputs: 2, digitalInputs: 8,  lineOutputs: 4, digitalOutputs: 8,  inserts: 2)
    public static let iD24    = DeviceModel(name: "iD24",      productID: 0x000D, micInputs: 2, digitalInputs: 10, lineOutputs: 4, digitalOutputs: 14, inserts: 2)
    public static let iD44    = DeviceModel(name: "iD44",      productID: 0x0005, micInputs: 4, digitalInputs: 16, lineOutputs: 4, digitalOutputs: 16, inserts: 2, isVerified: true)
    public static let iD44mkII = DeviceModel(name: "iD44 MkII", productID: 0x000B, micInputs: 4, digitalInputs: 16, lineOutputs: 4, digitalOutputs: 16, inserts: 2)
    public static let iD48    = DeviceModel(name: "iD48",      productID: 0x0012, micInputs: 8, digitalInputs: 16, lineOutputs: 4, digitalOutputs: 16, inserts: 8)

    /// All known iD models.
    public static let all: [DeviceModel] = [
        iD4, iD4mkII, iD14, iD14mkII, iD22, iD24, iD44, iD44mkII, iD48,
    ]

    /// The model for a given USB product ID, if known.
    public static func model(forProductID productID: Int) -> DeviceModel? {
        all.first { $0.productID == productID }
    }
}
