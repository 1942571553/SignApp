import Foundation
import SwiftUI
import UIKit
import ZIPFoundation
import Zsign

enum YFiles {
    static var root: URL {
        let url = URL.yDocuments.appendingPathComponent("YixiangPro", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static var unsigned: URL { directory("Unsigned") }
    static var signed: URL { directory("Signed") }
    static var certs: URL { directory("Certificates") }
    static var cache: URL { directory("Cache") }
    static var installs: URL { directory("Installs") }

    static func directory(_ name: String) -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func json<T: Codable>(_ value: T, at url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .secondsSince1970
        if let data = try? encoder.encode(value) { try? data.write(to: url, options: .atomic) }
    }

    static func read<T: Codable>(_ type: T.Type, at url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(T.self, from: data)
    }
}

struct StoreItem: Identifiable {
    let source: RemoteSource
    let app: RepoApp
    var id: String { "\(source.id)::\(app.appID)" }
}

final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var config: ClientConfig?
    @Published var sources: [RemoteSource] = []
    @Published var apps: [StoreItem] = []
    @Published var user: UserInfo?
    @Published var certificates: [CertificateRecord] = []
    @Published var imported: [ImportedApp] = []
    @Published var signed: [SignedApp] = []
    @Published var isLoading = false
    @Published var message: String?
    @Published var authBusy = false
    @Published var lastSync: Date?
    @Published var route: DeepLinkRoute?
    @Published var requestedTab: String?
    @Published var requestedAccount = false
    @Published var patchDeepLinkURL: String?

    private var sourceStates: [String: Bool] = [:]
    private let configCache = YFiles.root.appendingPathComponent("config.json")
    private let certIndex = YFiles.certs.appendingPathComponent("index.json")
    private let importedIndex = YFiles.unsigned.appendingPathComponent("index.json")
    private let signedIndex = YFiles.signed.appendingPathComponent("index.json")

    private init() {
        certificates = YFiles.read([CertificateRecord].self, at: certIndex) ?? []
        imported = YFiles.read([ImportedApp].self, at: importedIndex) ?? []
        signed = YFiles.read([SignedApp].self, at: signedIndex) ?? []
        if let cached = YFiles.read(ClientConfig.self, at: configCache) {
            config = cached
            sources = cached.defaultSources ?? []
            user = cached.user
            sourceStates = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0.unlocked) })
        }
        refreshConfig()
        refreshStore()
    }

    var displayName: String { config?.brand?.name ?? "艺祥签" }
    var subtitle: String { config?.brand?.subtitle ?? "iOS 签名与资源管理" }
    var announcement: String? { config?.announcement ?? config?.brand?.announcement }
    var isLoggedIn: Bool { user != nil && APIClient.shared.token != nil }
    var globalLock: TimeLock? { config?.timeLock }
    var isGloballyLocked: Bool { config?.timeLock?.active == true }
    var allowStore: Bool { featureEnabled("store") }
    var allowSigning: Bool { featureEnabled("signing") }
    var allowInstall: Bool { featureEnabled("install") }
    var allowTools: Bool { featureEnabled("tools") }

    func featureEnabled(_ key: String) -> Bool {
        config?.features?[key] ?? true
    }
    var remainingDays: Int? {
        guard let expiry = user?.expiresAt else { return nil }
        return max(0, (expiry - Int(Date().timeIntervalSince1970)) / 86400)
    }

    func refreshConfig() {
        APIClient.shared.fetchConfig { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let value):
                self.config = value
                self.user = value.user
                self.sources = value.defaultSources ?? []
                self.sourceStates = Dictionary(uniqueKeysWithValues: self.sources.map { ($0.id, $0.unlocked) })
                self.lastSync = Date()
                YFiles.json(value, at: self.configCache)
                self.refreshStore()
            case .failure(let error):
                if self.config == nil { self.message = error.localizedDescription }
            }
        }
    }

    func refreshStore() {
        guard !isLoading else { return }
        isLoading = true
        let group = DispatchGroup()
        var collected: [StoreItem] = []
        let lock = NSLock()

        for source in sources where source.isTimeOpen && (!source.requiresCard || source.unlocked) {
            guard let url = source.urlValue else { continue }
            group.enter()
            APIClient.shared.fetchRepository(url) { result in
                defer { group.leave() }
                guard case .success(let repo) = result else { return }
                let items = (repo.apps ?? []).map { StoreItem(source: source, app: $0) }
                lock.lock()
                collected.append(contentsOf: items)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            var seen = Set<String>()
            self.apps = collected.filter { seen.insert($0.app.appID).inserted }.sorted { $0.app.displayName < $1.app.displayName }
            self.isLoading = false
        }
    }

    func redeem(code: String, completion: @escaping (Bool, String?) -> Void) {
        APIClient.shared.redeem(code: code) { [weak self] result in
            switch result {
            case .success(let value):
                if value.ok {
                    self?.refreshConfig()
                    completion(true, value.message)
                } else {
                    completion(false, value.message ?? "卡密无效")
                }
            case .failure(let error):
                completion(false, error.localizedDescription)
            }
        }
    }

    func login(username: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        authBusy = true
        APIClient.shared.login(username: username, password: password) { [weak self] result in
            self?.authBusy = false
            switch result {
            case .success(let value):
                guard value.ok, let token = value.token else {
                    completion(false, value.message ?? "登录失败"); return
                }
                APIClient.shared.token = token
                self?.refreshConfig()
                completion(true, nil)
            case .failure(let error):
                completion(false, error.localizedDescription)
            }
        }
    }

    func register(username: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        authBusy = true
        APIClient.shared.register(username: username, password: password) { [weak self] result in
            self?.authBusy = false
            switch result {
            case .success(let value):
                guard value.ok, let token = value.token else {
                    completion(false, value.message ?? "注册失败"); return
                }
                APIClient.shared.token = token
                self?.refreshConfig()
                completion(true, nil)
            case .failure(let error):
                completion(false, error.localizedDescription)
            }
        }
    }

    func logout() {
        APIClient.shared.token = nil
        user = nil
        refreshConfig()
    }

    // MARK: - Certificates
    func reloadCertificates() {
        certificates = YFiles.read([CertificateRecord].self, at: certIndex) ?? []
    }

    func saveCertificates() {
        YFiles.json(certificates, at: certIndex)
    }

    func addCertificate(_ record: CertificateRecord) {
        var record = record
        if certificates.isEmpty { record.isDefault = true }
        certificates.append(record)
        saveCertificates()
    }

    func deleteCertificate(_ record: CertificateRecord) {
        try? FileManager.default.removeItem(atPath: record.p12Path)
        try? FileManager.default.removeItem(atPath: record.provisionPath)
        let folder = URL(fileURLWithPath: record.p12Path).deletingLastPathComponent()
        try? FileManager.default.removeItem(at: folder)
        certificates.removeAll { $0.id == record.id }
        saveCertificates()
    }

    func defaultCertificate() -> CertificateRecord? {
        certificates.first(where: { $0.isDefault }) ?? certificates.first
    }

    // MARK: - Imported / signed
    func reloadImported() {
        imported = YFiles.read([ImportedApp].self, at: importedIndex) ?? []
    }

    func reloadSigned() {
        signed = YFiles.read([SignedApp].self, at: signedIndex) ?? []
    }

    func saveImported() { YFiles.json(imported, at: importedIndex) }
    func saveSigned() { YFiles.json(signed, at: signedIndex) }

    func deleteImported(_ app: ImportedApp) {
        try? FileManager.default.removeItem(atPath: app.ipaPath)
        let folder = URL(fileURLWithPath: app.ipaPath).deletingLastPathComponent()
        try? FileManager.default.removeItem(at: folder)
        imported.removeAll { $0.id == app.id }
        saveImported()
    }

    func deleteSigned(_ app: SignedApp) {
        try? FileManager.default.removeItem(atPath: app.ipaPath)
        let folder = URL(fileURLWithPath: app.ipaPath).deletingLastPathComponent()
        try? FileManager.default.removeItem(at: folder)
        signed.removeAll { $0.id == app.id }
        saveSigned()
    }

    func importIPA(_ url: URL, completion: @escaping (Bool, String?) -> Void) {
        let id = UUID().uuidString
        let folder = YFiles.unsigned.appendingPathComponent(id, isDirectory: true)
        let ipa = folder.appendingPathComponent("app.ipa")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            try FileManager.default.copyItem(at: url, to: ipa)
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let work = folder.appendingPathComponent("work", isDirectory: true)
                    try FileManager.default.unzipItem(at: ipa, to: work)
                    guard let appURL = try FileManager.default.contentsOfDirectory(at: work, includingPropertiesForKeys: nil)
                        .first(where: { $0.pathExtension == "app" }) else {
                        throw APIError(message: "IPA 里没有找到 .app")
                    }
                    let info = try Self.infoPlist(appURL)
                    let name = info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? appURL.deletingPathExtension().lastPathComponent
                    let bundle = info["CFBundleIdentifier"] as? String ?? ""
                    let version = info["CFBundleShortVersionString"] as? String ?? ""
                    let minOS = info["MinimumOSVersion"] as? String ?? ""
                    let icon = try? Self.copyIcon(from: appURL, to: folder)
                    let record = ImportedApp(id: id, name: name, bundleID: bundle, version: version, minOS: minOS, iconPath: icon?.path, ipaPath: ipa.path, appPath: appURL.path, importedAt: Date())
                    DispatchQueue.main.async {
                        self.imported.insert(record, at: 0)
                        self.saveImported()
                        completion(true, nil)
                    }
                } catch {
                    DispatchQueue.main.async { completion(false, error.localizedDescription) }
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    func sign(_ app: ImportedApp, certificate: CertificateRecord, options: SignOptions, completion: @escaping (Bool, String?) -> Void) {
        let id = UUID().uuidString
        let folder = YFiles.signed.appendingPathComponent(id, isDirectory: true)
        let payload = folder.appendingPathComponent("Payload", isDirectory: true)
        let target = payload.appendingPathComponent(URL(fileURLWithPath: app.appPath).lastPathComponent, isDirectory: true)
        let output = folder.appendingPathComponent("signed.ipa")

        do {
            try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: URL(fileURLWithPath: app.appPath), to: target)
            try Self.patchInfo(target, options: options)
            if options.removePlugIns {
                try? FileManager.default.removeItem(at: target.appendingPathComponent("PlugIns"))
            }
            if options.removeWatch {
                try? FileManager.default.removeItem(at: target.appendingPathComponent("Watch"))
            }
            if let dylibPath = options.injectDylibPath {
                let dylib = URL(fileURLWithPath: dylibPath)
                let destination = target.appendingPathComponent(dylib.lastPathComponent)
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.copyItem(at: dylib, to: destination)
                let executable = target.appendingPathComponent(try Self.infoPlist(target)["CFBundleExecutable"] as? String ?? target.deletingPathExtension().lastPathComponent)
                _ = Zsign.injectDyLib(appExecutable: executable.path, with: "@executable_path/\(dylib.lastPathComponent)", weak: true)
            }
            let ent = try Self.entitlements(from: certificate.provisionPath)
            let entURL = folder.appendingPathComponent("entitlements.plist")
            try ent.write(to: entURL, atomically: true, encoding: .utf8)
            DispatchQueue.global(qos: .userInitiated).async {
                let ok = Zsign.sign(
                    appPath: target.path,
                    provisionPath: certificate.provisionPath,
                    p12Path: certificate.p12Path,
                    p12Password: certificate.password,
                    entitlementsPath: entURL.path,
                    customIdentifier: options.bundleID,
                    customName: options.name,
                    customVersion: options.version
                )
                guard ok else {
                    DispatchQueue.main.async { completion(false, "签名失败，请检查证书、描述文件或密码") }
                    return
                }
                do {
                    try FileManager.default.zipItem(at: folder, to: output, shouldKeepParent: false)
                    let icon = try? Self.copyIcon(from: target, to: folder)
                    let record = SignedApp(id: id, name: options.name, bundleID: options.bundleID, version: options.version, iconPath: icon?.path, ipaPath: output.path, appPath: target.path, certificateName: certificate.name, signedAt: Date(), installURL: nil)
                    DispatchQueue.main.async {
                        self.signed.insert(record, at: 0)
                        self.saveSigned()
                        completion(true, nil)
                    }
                } catch {
                    DispatchQueue.main.async { completion(false, error.localizedDescription) }
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    func install(_ app: SignedApp, completion: @escaping (Bool, String?) -> Void) {
        let ipa = URL(fileURLWithPath: app.ipaPath)
        APIClient.shared.uploadInstall(ipaURL: ipa, app: app) { [weak self] result in
            switch result {
            case .success(let value):
                guard value.ok, let manifest = value.manifestURL, let url = URL(string: manifest) else {
                    completion(false, value.message ?? "上传失败"); return
                }
                var record = app
                record.installURL = value.pageURL
                if let index = self?.signed.firstIndex(where: { $0.id == app.id }) {
                    self?.signed[index] = record
                    self?.saveSigned()
                }
                let itms = URL(string: "itms-services://?action=download-manifest&url=\(manifest.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? manifest)")!
                DispatchQueue.main.async {
                    UIApplication.shared.open(itms, options: [:]) { success in
                        completion(success, success ? nil : "无法打开安装链接")
                    }
                }
            case .failure(let error):
                completion(false, error.localizedDescription)
            }
        }
    }

    // MARK: - Helpers
    static func infoPlist(_ app: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: app.appendingPathComponent("Info.plist"))
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw APIError(message: "Info.plist 格式错误")
        }
        return plist
    }

    static func patchInfo(_ app: URL, options: SignOptions) throws {
        let url = app.appendingPathComponent("Info.plist")
        var plist = try infoPlist(app)
        plist["CFBundleDisplayName"] = options.name
        plist["CFBundleName"] = options.name
        plist["CFBundleIdentifier"] = options.bundleID
        plist["CFBundleShortVersionString"] = options.version
        if !options.minOS.isEmpty { plist["MinimumOSVersion"] = options.minOS }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url)
    }

    static func entitlements(from provisionPath: String) throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: provisionPath))
        guard let range = data.range(of: Data("<?xml".utf8)) else {
            throw APIError(message: "描述文件不是有效的 mobileprovision")
        }
        let xml = data.subdata(in: range.lowerBound..<data.endIndex)
        guard let plist = try PropertyListSerialization.propertyList(from: xml, options: [], format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any] else {
            throw APIError(message: "描述文件没有 Entitlements")
        }
        let entData = try PropertyListSerialization.data(fromPropertyList: entitlements, format: .xml, options: 0)
        guard let string = String(data: entData, encoding: .utf8) else {
            throw APIError(message: "无法写入 entitlements")
        }
        return string
    }

    static func copyIcon(from app: URL, to folder: URL) throws -> URL {
        let candidates = ["AppIcon60x60@2x.png", "AppIcon76x76@2x~ipad.png", "AppIcon60x60@3x.png"]
        for name in candidates {
            let source = app.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: source.path) {
                let target = folder.appendingPathComponent("icon.png")
                try? FileManager.default.removeItem(at: target)
                try FileManager.default.copyItem(at: source, to: target)
                return target
            }
        }
        throw APIError(message: "没有找到应用图标")
    }
}
