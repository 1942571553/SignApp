import Foundation
import Security
import UIKit

final class CertificateManager {
    static let shared = CertificateManager()

    func importCertificate(
        p12URL: URL,
        provisionURL: URL,
        password: String,
        nickname: String?,
        completion: @escaping (Bool, String?) -> Void
    ) {
        let id = UUID().uuidString
        let folder = YFiles.certs.appendingPathComponent(id, isDirectory: true)
        let p12 = folder.appendingPathComponent("cert.p12")
        let provision = folder.appendingPathComponent("profile.mobileprovision")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let p12Scoped = p12URL.startAccessingSecurityScopedResource()
            let provisionScoped = provisionURL.startAccessingSecurityScopedResource()
            defer {
                if p12Scoped { p12URL.stopAccessingSecurityScopedResource() }
                if provisionScoped { provisionURL.stopAccessingSecurityScopedResource() }
            }
            try FileManager.default.copyItem(at: p12URL, to: p12)
            try FileManager.default.copyItem(at: provisionURL, to: provision)

            guard validateP12(p12, password: password) else {
                throw APIError(message: "P12 密码错误或文件无效")
            }
            let profile = try readProfile(provision)
            let name = nickname?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? profile.name
                ?? "未命名证书"
            let expiration = profile.expiration ?? Date().addingTimeInterval(86400 * 365)
            let record = CertificateRecord(
                id: id,
                name: name,
                teamName: profile.teamName ?? "",
                expiration: expiration,
                p12Path: p12.path,
                provisionPath: provision.path,
                password: password,
                isDefault: false
            )
            DispatchQueue.main.async {
                AppModel.shared.addCertificate(record)
                completion(true, nil)
            }
        } catch {
            try? FileManager.default.removeItem(at: folder)
            completion(false, error.localizedDescription)
        }
    }

    private func validateP12(_ url: URL, password: String) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        var items: CFArray?
        let options = [kSecImportExportPassphrase as String: password] as CFDictionary
        let status = SecPKCS12Import(data as CFData, options, &items)
        return status == errSecSuccess && (items as? [[String: Any]])?.isEmpty == false
    }

    private func readProfile(_ url: URL) throws -> (name: String?, teamName: String?, expiration: Date?) {
        let data = try Data(contentsOf: url)
        guard let range = data.range(of: Data("<?xml".utf8)) else {
            throw APIError(message: "描述文件格式错误")
        }
        let xml = data.subdata(in: range.lowerBound..<data.endIndex)
        guard let plist = try PropertyListSerialization.propertyList(from: xml, options: [], format: nil) as? [String: Any] else {
            throw APIError(message: "描述文件解析失败")
        }
        return (
            plist["Name"] as? String,
            plist["TeamName"] as? String,
            plist["ExpirationDate"] as? Date
        )
    }
}

private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
