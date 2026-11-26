import SwiftUI
import UIKit
import Zsign

struct DeveloperToolsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var certID = ""
    @State private var checking = false
    @State private var revokeResult: String?

    private var cert: CertificateRecord? {
        model.certificates.first(where: { $0.id == certID }) ?? model.defaultCertificate()
    }

    var body: some View {
        ToolPage(title: "开发者工具") {
            developerSection
            certificateSection
            patchSection
            distributionSection
            profileSection
            Text("证书私钥只在本机使用；所有对外链接会跳转到 Apple 官方页面。")
                .font(.caption2).foregroundColor(YTheme.muted)
        }
    }

    private var developerSection: some View {
        VStack(spacing: 0) {
            YSectionTitle(title: "Apple 开发者").padding(.bottom, 8)
            linkRow("开发者账号", "管理会员资格、团队与协议", "person.badge.key.fill", YTheme.purple, "https://developer.apple.com/account")
            Divider().padding(.leading, 45)
            linkRow("证书 / 标识符 / 描述文件", "创建 Certificates、App ID 与 Profile", "checkmark.seal.fill", YTheme.green, "https://developer.apple.com/account/resources/certificates/list")
            Divider().padding(.leading, 45)
            linkRow("App Store Connect", "P8 密钥、TestFlight 与 App 管理", "storefront.fill", YTheme.blue, "https://appstoreconnect.apple.com")
            Divider().padding(.leading, 45)
            linkRow("UDID 登记", "用描述文件采集当前设备 UDID", "number", YTheme.cyan, nil)
        }.yCard(14)
    }

    private var certificateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            YSectionTitle(title: "证书检测")
            if model.certificates.isEmpty {
                Text("先在证书管理中导入 p12 与描述文件").font(.caption).foregroundColor(YTheme.muted)
            } else {
                Menu {
                    ForEach(model.certificates) { item in
                        Button(item.name) { certID = item.id }
                    }
                } label: {
                    HStack {
                        Image(systemName: "seal.fill").foregroundColor(YTheme.purple)
                        Text(cert?.name ?? "选择证书").font(.subheadline).foregroundColor(YTheme.text)
                        Spacer()
                        Image(systemName: "chevron.down").foregroundColor(YTheme.muted)
                    }
                    .padding(11).background(YTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                if let cert {
                    YInfoLine(title: "到期", value: cert.expirationText)
                    YInfoLine(title: "团队", value: cert.teamName.isEmpty ? "—" : cert.teamName)
                }
                YPrimaryButton(title: checking ? "检测中…" : "OCSP 检测证书吊销状态", icon: "waveform.path.ecg", enabled: !checking) {
                    checkRevocation()
                }
                if let revokeResult {
                    Text(revokeResult).font(.caption).foregroundColor(revokeResult.contains("正常") ? YTheme.green : YTheme.orange)
                }
            }
        }.yCard(14)
    }

    private var patchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            YSectionTitle(title: "App 补丁")
            Text("签名前可修改显示名、Bundle ID、版本、最低系统版本，删除 PlugIns / Watch，或注入 Dylib。打开“已签名 → 待签名 → 签名”即可使用。")
                .font(.caption).foregroundColor(YTheme.muted).lineSpacing(2)
            HStack(spacing: 8) {
                YSoftPill(title: "名称替换", color: YTheme.purple)
                YSoftPill(title: "Bundle ID", color: YTheme.blue)
                YSoftPill(title: "去插件", color: YTheme.orange)
                YSoftPill(title: "Dylib 注入", color: YTheme.violet)
            }
        }.yCard(14)
    }

    private var distributionSection: some View {
        VStack(spacing: 0) {
            YSectionTitle(title: "分发").padding(.bottom, 8)
            NavigationLink(destination: DistributeView().environmentObject(model)) {
                toolRow("二维码分发", "上传签名 IPA 并生成安装二维码", "qrcode", YTheme.blue)
            }.buttonStyle(PlainButtonStyle())
            Divider().padding(.leading, 45)
            NavigationLink(destination: UDIDView().environmentObject(model)) {
                toolRow("UDID 获取", "描述文件登记设备真实 UDID", "number", YTheme.cyan)
            }.buttonStyle(PlainButtonStyle())
        }.yCard(14)
    }

    private var profileSection: some View {
        VStack(spacing: 0) {
            YSectionTitle(title: "配置描述文件").padding(.bottom, 8)
            NavigationLink(destination: WiFiProfileView()) {
                toolRow("Wi-Fi 描述文件", "生成 .mobileconfig，分享给设备安装", "wifi", YTheme.green)
            }.buttonStyle(PlainButtonStyle())
        }.yCard(14)
    }

    private func linkRow(_ title: String, _ subtitle: String, _ icon: String, _ color: Color, _ urlString: String?) -> some View {
        Button {
            if let urlString, let url = URL(string: urlString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                model.requestedTab = "tools"
                model.message = "请使用工具箱中的 UDID 获取"
            }
        } label: {
            toolRow(title, subtitle, icon, color)
        }.buttonStyle(PlainButtonStyle())
    }

    private func toolRow(_ title: String, _ subtitle: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundColor(color)
                .frame(width: 30, height: 30).background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).foregroundColor(YTheme.text)
                Text(subtitle).font(.caption2).foregroundColor(YTheme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundColor(YTheme.muted.opacity(0.55))
        }.padding(.vertical, 8)
    }

    private func checkRevocation() {
        guard let cert else { return }
        checking = true
        Zsign.checkRevokage(provisionPath: cert.provisionPath, p12Path: cert.p12Path, p12Password: cert.password) { status, date, error in
            DispatchQueue.main.async {
                checking = false
                switch status {
                case 0: revokeResult = "证书状态正常（OCSP 未吊销）"
                case 1: revokeResult = "证书已被吊销，请更换证书"
                default: revokeResult = "无法确认：\(error ?? "OCSP 无响应")"
                }
            }
        }
    }
}

struct WiFiProfileView: View {
    @Environment(\.presentationMode) private var presentation
    @State private var ssid = ""
    @State private var password = ""
    @State private var shareURL: URL?
    @State private var error: String?

    var body: some View {
        ToolPage(title: "Wi-Fi 描述文件") {
            VStack(alignment: .leading, spacing: 10) {
                YSectionTitle(title: "生成 .mobileconfig")
                Text("填写 Wi-Fi 信息，生成未签名的配置描述文件。可通过 AirDrop / 文件分享安装，iOS 会提示安装描述文件。")
                    .font(.caption).foregroundColor(YTheme.muted)
                TextField("Wi-Fi 名称 SSID", text: $ssid).padding(11).background(YTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
                SecureField("Wi-Fi 密码", text: $password).padding(11).background(YTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
                YPrimaryButton(title: "生成并分享", icon: "square.and.arrow.up", enabled: !ssid.isEmpty) { generate() }
                if let error { Text(error).font(.caption).foregroundColor(YTheme.red) }
            }.yCard(14)
            Text("仅用于自己的设备；请勿分发他人的网络配置。").font(.caption2).foregroundColor(YTheme.muted)
        }
        .sheet(item: Binding(get: { shareURL.map { FileURL(url: $0) } }, set: { _ in shareURL = nil })) { file in
            ShareSheet(items: [file.url])
        }
    }

    private func generate() {
        do {
            let payload: [String: Any] = [
                "PayloadType": "WiFi",
                "PayloadIdentifier": "com.yixiangsign.wifi.\(UUID().uuidString)",
                "PayloadUUID": UUID().uuidString,
                "PayloadVersion": 1,
                "PayloadDisplayName": ssid,
                "SSID_STR": ssid,
                "AutoJoin": true,
                "EncryptionType": "WPA",
                "Password": password
            ]
            let profile: [String: Any] = [
                "PayloadContent": [payload],
                "PayloadDisplayName": "Wi-Fi：\(ssid)",
                "PayloadIdentifier": "com.yixiangsign.wifi.profile.\(UUID().uuidString)",
                "PayloadOrganization": "Yixiang",
                "PayloadType": "Configuration",
                "PayloadUUID": UUID().uuidString,
                "PayloadVersion": 1
            ]
            let data = try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
            let url = YFiles.cache.appendingPathComponent("WiFi-\(ssid.replacingOccurrences(of: " ", with: "-")).mobileconfig")
            try data.write(to: url, options: .atomic)
            shareURL = url
        } catch {
            self.error = error.localizedDescription
        }
    }
}
