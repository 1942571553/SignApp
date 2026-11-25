import Foundation
import ZIPFoundation

enum IPAMetadata {
    /// 从 ipa 里读出 Payload/*.app/Info.plist 的 CFBundleIdentifier
    static func bundleIdentifier(of ipa: URL) -> String? {
        guard let archive = Archive(url: ipa, accessMode: .read) else { return nil }
        guard let entry = archive.first(where: { $0.path.hasSuffix(".app/Info.plist") }) else { return nil }

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-Info.plist")
        defer { try? FileManager.default.removeItem(at: tmp) }

        do {
            _ = try archive.extract(entry, to: tmp)
            let data = try Data(contentsOf: tmp)
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
            if let dict = plist as? [String: Any], let bid = dict["CFBundleIdentifier"] as? String {
                return bid
            }
            return nil
        } catch {
            return nil
        }
    }

    static func displayName(of ipa: URL) -> String? {
        guard let archive = Archive(url: ipa, accessMode: .read) else { return nil }
        guard let entry = archive.first(where: { $0.path.hasSuffix(".app/Info.plist") }) else { return nil }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-Info.plist")
        defer { try? FileManager.default.removeItem(at: tmp) }
        guard (try? archive.extract(entry, to: tmp)) != nil,
              let data = try? Data(contentsOf: tmp),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any] else { return nil }
        return (dict["CFBundleDisplayName"] as? String) ?? (dict["CFBundleName"] as? String)
    }
}
