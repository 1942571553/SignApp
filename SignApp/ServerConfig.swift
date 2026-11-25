import Foundation

/// 站点地址的读写与规范化
enum ServerConfig {
    private static let key = "sign.server.url"

    /// 打包时可通过 Info.plist 的 DefaultServerURL 预置站点，第一次打开直接进站
    static var bundledDefault: String {
        (Bundle.main.object(forInfoDictionaryKey: "DefaultServerURL") as? String) ?? ""
    }

    static var current: URL? {
        normalize(UserDefaults.standard.string(forKey: key) ?? bundledDefault)
    }

    static var rawValue: String {
        UserDefaults.standard.string(forKey: key) ?? bundledDefault
    }

    @discardableResult
    static func save(_ raw: String) -> URL? {
        guard let url = normalize(raw) else { return nil }
        UserDefaults.standard.set(url.absoluteString, forKey: key)
        return url
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// 允许用户只输域名，自动补 https；拒绝非法地址
    static func normalize(_ raw: String) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if !text.lowercased().hasPrefix("http://") && !text.lowercased().hasPrefix("https://") {
            text = "https://" + text
        }

        guard let url = URL(string: text),
              let host = url.host,
              !host.isEmpty,
              host.contains(".") || host == "localhost" || host.hasPrefix("192.168.")
        else {
            return nil
        }

        return url
    }
}
