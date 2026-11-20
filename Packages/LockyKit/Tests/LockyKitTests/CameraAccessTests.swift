import CryptoKit
import Foundation
import Testing
@testable import LockyKit

struct CameraAccessTests {
    private func status(cameraAccess: CameraAccess?) -> MacStatus {
        .init(
            macID: .init(),
            name: "MacBook Pro",
            model: "Mac16,7",
            productName: "MacBook Pro",
            family: .macBook,
            systemVersion: "27.2",
            userName: "Alex",
            lockState: .unlocked,
            lockStateDate: .now,
            isAutoLockEnabled: true,
            unlockCount: 3,
            cameraAccess: cameraAccess
        )
    }

    @Test(arguments: CameraAccess.allCases)
    func statusCarriesTheCameraAccess(access: CameraAccess) throws {
        let original: MacStatus = status(cameraAccess: access)
        let decoded: MacStatus = try JSONDecoder().decode(MacStatus.self, from: JSONEncoder().encode(original))
        #expect(decoded.cameraAccess == access)
    }

    /// A Mac that does not report its camera yet (or a cached status) still decodes.
    @Test
    func statusWithoutCameraAccessDecodes() throws {
        var json: [String: Any] = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(status(cameraAccess: .authorized))) as? [String: Any])
        json.removeValue(forKey: "cameraAccess")
        let decoded: MacStatus = try JSONDecoder().decode(MacStatus.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.cameraAccess == nil)
    }

    @Test
    func onlyAnAllowedCameraTakesPhotos() {
        #expect(CameraAccess.allCases.filter(\.canTakePhotos) == [.authorized])
    }

    @Test
    func cameraAccessRequestIsEncrypted() throws {
        #expect(throws: LockyProtocolError.encryptionRequired) {
            try WireCodec.encodeClearText(.cameraAccessRequest)
        }
        let key: SymmetricKey = .init(size: .bits256)
        let macNonce: Data = .randomBytes(count: 32)
        let phoneNonce: Data = .randomBytes(count: 32)
        var phone: SecureChannel = .init(pairingKey: key, macNonce: macNonce, phoneNonce: phoneNonce, role: .phone)
        var mac: SecureChannel? = .init(pairingKey: key, macNonce: macNonce, phoneNonce: phoneNonce, role: .mac)
        let payload: Data = try WireCodec.encodeEncrypted(.cameraAccessRequest, channel: &phone)
        #expect(try WireCodec.decode(payload, channel: &mac) == .cameraAccessRequest)
    }
}
