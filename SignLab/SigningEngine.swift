import Foundation
import RorkSign

enum SigningFailure: LocalizedError {
    case missing(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .missing(let what): return "缺少\(what)"
        case .failed(let msg): return msg
        }
    }
}

struct SigningResult {
    let output: URL
}

enum SigningEngine {
    static func sign(ipa: URL, p12: URL, prov: URL, password: String, bundleID: String) throws -> SigningResult {
        let identityData = try Data(contentsOf: p12)
        let profileData = try Data(contentsOf: prov)

        let identity: SigningIdentity
        do {
            identity = try SigningIdentity(pkcs12Data: identityData, password: password)
        } catch {
            throw SigningFailure.failed("p12 读取失败，检查密码是否正确：\(error.localizedDescription)")
        }

        let outDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Signed", isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let base = ipa.deletingPathExtension().lastPathComponent
        let output = outDir.appendingPathComponent(base + "-signed.ipa")

        if FileManager.default.fileExists(atPath: output.path) {
            try? FileManager.default.removeItem(at: output)
        }

        do {
            _ = try RorkSigner.signIPA(
                at: ipa,
                outputURL: output,
                identity: identity,
                options: AppSigningOptions(
                    bundleIdentifier: bundleID,
                    rootProvisioningProfile: profileData
                )
            )
        } catch {
            throw SigningFailure.failed("签名失败：\(error.localizedDescription)")
        }

        return SigningResult(output: output)
    }
}
