import XCTest
@testable import OpenAudient

/// Hardware round-trip tests. Skipped unless `OPEN_AUDIENT_DEVICE=1` is set, so
/// CI and machines without an iD44 stay green. The Audient iD app must be quit.
///
///     OPEN_AUDIENT_DEVICE=1 swift test
final class DeviceIntegrationTests: XCTestCase {
    private func requireDevice() throws -> AudientDevice {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["OPEN_AUDIENT_DEVICE"] == "1",
            "Set OPEN_AUDIENT_DEVICE=1 to run hardware tests (quit the Audient iD app first)."
        )
        return try AudientDevice.openFirst()
    }

    func testCutRoundTrip() throws {
        let device = try requireDevice()
        let cut = Monitor.cut

        let original = try device.read(cut)
        addTeardownBlock { try? device.write(cut, original) }

        try device.write(cut, !original)
        XCTAssertEqual(try device.read(cut), !original, "device should reflect the written value")

        try device.write(cut, original)
        XCTAssertEqual(try device.read(cut), original, "device should restore the original value")
    }
}
