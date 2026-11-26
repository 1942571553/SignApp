import Foundation
import UIKit

enum DeepLinkManager {
    static func route(_ url: URL) -> DeepLinkRoute {
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "yixiang" || scheme == "yixiangsign" else {
            return .unknown(url.absoluteString)
        }
        let host = (url.host ?? "").lowercased()
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let action = host.isEmpty ? path : host
        let params = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            params.first(where: { $0.name.lowercased() == name })?.value?.removingPercentEncoding
        }
        switch action {
        case "", "open", "tab":
            return .tab(value("tab") ?? path.nonEmpty ?? "apps")
        case "addsource", "source":
            return .addSource(value("url") ?? "")
        case "install":
            return .install(value("url") ?? "")
        case "sign":
            return .sign(value("url") ?? "")
        case "redeem", "card":
            return .redeem(value("code") ?? "")
        case "udid":
            return .udid
        case "patch":
            return .patch(value("url") ?? "")
        case "account", "login":
            return .account
        case "apps", "signed", "files", "downloads", "tools", "settings":
            return .tab(action)
        default:
            return .unknown(url.absoluteString)
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

extension AppModel {
    func handleDeepLink(_ url: URL) {
        let route = DeepLinkManager.route(url)
        self.route = route
        switch route {
        case .tab(let tab):
            requestedTab = tab
        case .addSource(let raw):
            guard let link = URL(string: raw), link.scheme?.hasPrefix("http") == true else {
                message = "Deep Link 软件源地址无效"
                return
            }
            let source = RemoteSource(id: "manual-\(UUID().uuidString.prefix(8))", name: link.host ?? "外部软件源", url: raw, iconURL: nil, description: "通过 Deep Link 添加", requiresCard: false, price: nil, timeStart: nil, timeEnd: nil, unlocked: true, expiresAt: nil, sort: 999)
            if !sources.contains(where: { $0.url == raw }) {
                sources.append(source)
                refreshStore()
                message = "已添加软件源：\(source.name)"
            }
        case .install(let raw), .sign(let raw):
            guard let link = URL(string: raw) else { message = "Deep Link 下载地址无效"; return }
            downloadRemote(link)
        case .redeem(let code):
            guard !code.isEmpty else { message = "Deep Link 缺少卡密"; return }
            redeem(code: code) { ok, msg in
                self.message = ok ? (msg ?? "卡密兑换成功") : (msg ?? "卡密兑换失败")
            }
        case .udid:
            if let target = URL(string: "https://sign.yixsc.cn/api/udid/profile?device=\(APIClient.shared.deviceID)") {
                UIApplication.shared.open(target, options: [:], completionHandler: nil)
            }
        case .patch(let raw):
            requestedTab = "tools"
            patchDeepLinkURL = raw
            message = "已载入补丁任务"
        case .account:
            requestedAccount = true
        case .unknown(let value):
            message = "无法识别的 Deep Link：\(value)"
        }
    }

    func downloadRemote(_ url: URL) {
        message = "正在通过 Deep Link 下载 IPA…"
        URLSession.shared.downloadTask(with: url) { location, response, error in
            guard let location, error == nil else {
                DispatchQueue.main.async { self.message = error?.localizedDescription ?? "下载失败" }
                return
            }
            let folder = YFiles.unsigned.appendingPathComponent(UUID().uuidString, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let target = folder.appendingPathComponent("deeplink.ipa")
                try FileManager.default.moveItem(at: location, to: target)
                DispatchQueue.main.async {
                    self.importIPA(target) { ok, msg in
                        self.message = ok ? "Deep Link IPA 已导入，可前往已签名页" : (msg ?? "导入失败")
                        if ok { self.requestedTab = "signed" }
                    }
                }
            } catch {
                DispatchQueue.main.async { self.message = error.localizedDescription }
            }
        }.resume()
    }
}
