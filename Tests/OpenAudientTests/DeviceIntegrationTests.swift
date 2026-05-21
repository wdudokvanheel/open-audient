import XCTest
@testable import OpenAudient

/// Hardware round-trip tests. Skipped unless `OPEN_AUDIENT_DEVICE=1` is set, so
/// CI and machines without an iD44 stay green. The Audient iD app must be quit.
///
///     OPEN_AUDIENT_DEVICE=1 swift test
final class DeviceIntegrationTests: XCTestCase {
    private func requireDevice() async throws -> AudientDevice {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["OPEN_AUDIENT_DEVICE"] == "1",
            "Set OPEN_AUDIENT_DEVICE=1 to run hardware tests (quit the Audient iD app first)."
        )
        return try await AudientDevice.openFirst()
    }

    func testCutRoundTrip() async throws {
        let device = try await requireDevice()
        let cut = Monitor.cut

        let original = try await device.read(cut)
        addTeardownBlock { try? await device.write(cut, original) }

        try await device.write(cut, !original)
        let flipped = try await device.read(cut)
        XCTAssertEqual(flipped, !original, "device should reflect the written value")

        try await device.write(cut, original)
        let restored = try await device.read(cut)
        XCTAssertEqual(restored, original, "device should restore the original value")
    }
}
