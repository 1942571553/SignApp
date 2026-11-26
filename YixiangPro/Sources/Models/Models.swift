import Foundation

struct FlexibleDate: Codable, Hashable {
    let date: Date

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let value = try? c.decode(Double.self) {
            date = Date(timeIntervalSince1970: value > 10_000_000_000 ? value / 1000 : value)
            return
        }
        if let value = try? c.decode(String.self) {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: value) { date = d; return }
            iso.formatOptions = [.withInternetDateTime]
            if let d = iso.date(from: value) { date = d; return }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            if let d = formatter.date(from: value) { date = d; return }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid date: \(value)")
        }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid date")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(date.timeIntervalSince1970)
    }
}

struct FlexString: Codable, Hashable {
    let value: String
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s; return }
        if let i = try? c.decode(Int.self) { value = String(i); return }
        value = ""
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
}

struct RepoApp: Codable, Hashable {
    var id: String?
    var bundleIdentifier: String?
    var name: String?
    var subtitle: String?
    var developer: String?
    var version: String?
    var versionDate: FlexibleDate?
    var versionDescription: String?
    var downloadURL: String?
    var iconURL: String?
    var size: Int64?
    var category: String?
    var localizedDescription: String?
    var description: String?
    var type: FlexString?

    var displayName: String { name ?? bundleIdentifier ?? "未命名应用" }
    var bundleID: String { bundleIdentifier ?? id ?? "" }
    var downloadLink: URL? { downloadURL.flatMap(URL.init(string:)) }
    var iconLink: URL? { iconURL.flatMap(URL.init(string:)) }
    var summary: String {
        let value = localizedDescription ?? description ?? subtitle ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var appID: String { bundleID.isEmpty ? "\(displayName)::\(downloadURL ?? UUID().uuidString)" : bundleID }
}

struct Repository: Codable {
    var name: String?
    var identifier: String?
    var apps: [RepoApp]?
    var iconURL: String?
    var website: String?
}

struct RemoteSource: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var url: String
    var iconURL: String?
    var description: String?
    var requiresCard: Bool
    var price: String?
    var timeStart: Int?
    var timeEnd: Int?
    var unlocked: Bool
    var expiresAt: Int?
    var sort: Int?

    var urlValue: URL? { URL(string: url) }
    var iconLink: URL? { iconURL.flatMap(URL.init(string:)) }
    var isTimeOpen: Bool {
        let now = Int(Date().timeIntervalSince1970)
        if let start = timeStart, now < start { return false }
        if let end = timeEnd, now > end { return false }
        return true
    }
    var lockReason: String? {
        if !isTimeOpen {
            return timeEnd != nil ? "当前软件源未开放" : "暂未开放"
        }
        if requiresCard && !unlocked { return "需要卡密解锁" }
        return nil
    }
}

struct TimeLock: Codable, Hashable {
    var start: Int?
    var end: Int?
    var active: Bool
    var reason: String?
}

struct ClientFlags: Codable, Hashable {
    var allowSign: Bool?
    var allowInstall: Bool?
    var allowStore: Bool?
    var allowTools: Bool?
    var forceUpdate: Bool?
    var minVersion: String?
    var version: String?
    var downloadURL: String?
}

struct BrandInfo: Codable, Hashable {
    var name: String?
    var subtitle: String?
    var announcement: String?
    var supportURL: String?
    var logoURL: String?
}

struct UserInfo: Codable, Identifiable, Hashable {
    var id: Int
    var username: String
    var role: String?
    var expiresAt: Int?
    var createdAt: Int?
    var status: String?
}

struct ClientConfig: Codable {
    var ok: Bool
    var brand: BrandInfo?
    var client: ClientFlags?
    var announcement: String?
    var serverTime: Int?
    var defaultSources: [RemoteSource]?
    var timeLock: TimeLock?
    var user: UserInfo?
    var features: [String: Bool]?
    var message: String?
}

struct AuthResponse: Codable {
    var ok: Bool
    var token: String?
    var user: UserInfo?
    var message: String?
}

struct RedeemResponse: Codable {
    var ok: Bool
    var sourceId: String?
    var expiresAt: Int?
    var message: String?
}

struct InstallUploadResponse: Codable {
    var ok: Bool
    var manifestURL: String?
    var pageURL: String?
    var installToken: String?
    var message: String?
}

struct CertificateRecord: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var teamName: String
    var expiration: Date
    var p12Path: String
    var provisionPath: String
    var password: String
    var isDefault: Bool
}

struct ImportedApp: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var bundleID: String
    var version: String
    var minOS: String
    var iconPath: String?
    var ipaPath: String
    var appPath: String
    var importedAt: Date
}

struct SignedApp: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var bundleID: String
    var version: String
    var iconPath: String?
    var ipaPath: String
    var appPath: String
    var certificateName: String
    var signedAt: Date
    var installURL: String?
}

struct SignOptions {
    var name: String
    var bundleID: String
    var version: String
    var minOS: String = ""
    var removePlugIns: Bool = false
    var removeWatch: Bool = false
    var injectDylibPath: String? = nil
}

enum DeepLinkRoute: Equatable {
    case tab(String)
    case addSource(String)
    case install(String)
    case sign(String)
    case redeem(String)
    case udid
    case patch(String)
    case account
    case unknown(String)
}
