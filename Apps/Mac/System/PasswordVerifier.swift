import Foundation
import OpenDirectory

/// Checks the macOS session password with OpenDirectory.
///
/// Replaces the former `echo password | sudo -S ls` trick, which leaked the password into a shell
/// and required the user to be an administrator.
enum PasswordVerifier {
    static func verify(_ password: String) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            do {
                let node: ODNode = try .init(session: .default(), type: ODNodeType(kODNodeTypeAuthentication))
                let record: ODRecord = try node.record(withRecordType: kODRecordTypeUsers, name: NSUserName(), attributes: nil)
                try record.verifyPassword(password)
                return true
            } catch {
                return false
            }
        }.value
    }
}
