import Foundation
import XCTest
@testable import KeyClean

final class UpdateSecurityTests: XCTestCase {
    func testCorruptDMGIsRejectedBeforeInstall() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let artifact = directory.appendingPathComponent("KeyClean.dmg")
        try Data("corrupt".utf8).write(to: artifact)
        let manifest = UpdateManifest(
            version: "1.0.0",
            asset: "KeyClean.dmg",
            sha256: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            bundleIdentifier: "dev.local.KeyClean",
            teamIdentifier: "66K3EFBVB6"
        )

        XCTAssertThrowsError(
            try UpdateSecurity.verify(
                manifest: manifest,
                artifactURL: artifact,
                expectedVersion: "1.0.0",
                expectedAsset: "KeyClean.dmg",
                expectedBundleIdentifier: "dev.local.KeyClean"
            )
        ) {
            XCTAssertEqual($0 as? UpdateSecurityError, .checksumMismatch)
        }
    }
}
