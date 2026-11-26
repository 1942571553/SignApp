import SwiftUI
import UIKit
import ZIPFoundation
import CoreImage.CIFilterBuiltins
import Darwin
import CFNetwork
import UniformTypeIdentifiers

struct ToolItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: AnyView
}

struct ToolsView: View {
    @EnvironmentObject private var model: AppModel

    private var tools: [ToolItem] {
        [
            ToolItem(title: "系统信息", subtitle: "设备 / 存储 / 版本", icon: "cpu", color: YTheme.purple, destination: AnyView(SystemInfoView())),
            ToolItem(title: "设备安全", subtitle: "越狱 / 代理检测", icon: "lock.shield.fill", color: YTheme.green, destination: AnyView(DeviceSecurityView())),
            ToolItem(title: "网络检测", subtitle: "服务端连通性", icon: "network", color: YTheme.blue, destination: AnyView(NetworkCheckView())),
            ToolItem(title: "安装包分析", subtitle: "解析 IPA 信息", icon: "shippingbox.fill", color: YTheme.orange, destination: AnyView(IPAInspectView())),
            ToolItem(title: "证书检测", subtitle: "到期 / 状态", icon: "checkmark.seal.fill", color: YTheme.violet, destination: AnyView(CertificateCheckView())),
            ToolItem(title: "缓存清理", subtitle: "释放本机空间", icon: "trash.fill", color: YTheme.pink, destination: AnyView(CacheCleanView())),
            ToolItem(title: "UDID 获取", subtitle: "描述文件登记", icon: "number", color: YTheme.cyan, destination: AnyView(UDIDView())),
            ToolItem(title: "二维码分发", subtitle: "上传并生成链接", icon: "qrcode", color: YTheme.blue, destination: AnyView(DistributeView())),
            ToolItem(title: "开发者工具", subtitle: "证书 / 补丁 / 分发", icon: "hammer.fill", color: YTheme.violet, destination: AnyView(DeveloperToolsView().environmentObject(model))),
            ToolItem(title: "签名环境", subtitle: "zsign / 证书检查", icon: "signature", color: YTheme.purple, destination: AnyView(SigningEnvironmentView())),
            ToolItem(title: "文件导出", subtitle: "分享沙盒文件", icon: "square.and.arrow.up", color: YTheme.orange, destination: AnyView(FileExportView()))
        ]
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    if let announcement = model.announcement, !announcement.isEmpty {
                        HStack(spacing: 9) {
                            Image(systemName: "sparkles").foregroundColor(YTheme.purple)
                            Text(announcement).font(.caption).foregroundColor(YTheme.text).lineLimit(2)
                            Spacer()
                        }.yCard(11)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(tools) { tool in
                            NavigationLink(destination: tool.destination) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Image(systemName: tool.icon)
                                        .font(.system(size: 21, weight: .semibold))
                                        .foregroundColor(tool.color)
                                        .frame(width: 42, height: 42)
                                        .background(tool.color.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    Text(tool.title).font(.system(size: 14, weight: .semibold)).foregroundColor(YTheme.text)
                                    Text(tool.subtitle).font(.system(size: 9.5)).foregroundColor(YTheme.muted).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(13)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(YTheme.border, lineWidth: 0.7))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    Text("工具能力由客户端本地执行，部分功能需要服务端配合。")
                        .font(.caption2).foregroundColor(YTheme.muted)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(YTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(YTheme.coolGradient)
            Circle().fill(Color.white.opacity(0.14)).frame(width: 160, height: 160).offset(x: 55, y: -70)
            VStack(alignment: .leading, spacing: 7) {
                Text("工具箱").font(.system(size: 26, weight: .heavy)).foregroundColor(.white)
                Text("设备管理、签名检测与分发工具").font(.caption).foregroundColor(.white.opacity(0.78))
                HStack(spacing: 8) {
                    YSoftPill(title: "zsign 内核", color: .white.opacity(0.15))
                    YSoftPill(title: "iOS 15+", color: .white.opacity(0.15))
                }
                .padding(.top, 5)
            }
            .padding(18)
        }
        .frame(height: 132)
        .clipped()
    }
}

struct ToolPage<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) { content }
                .padding(16)
        }
        .background(YTheme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
    }
}

struct SystemInfoView: View {
    var body: some View {
        ToolPage(title: "系统信息") {
            infoCard
            storageCard
            appCard
        }
    }

    private var infoCard: some View {
        VStack(spacing: 10) {
            YSectionTitle(title: "设备")
            YInfoLine(title: "设备名称", value: UIDevice.current.name)
            YInfoLine(title: "系统版本", value: UIDevice.current.systemName + " " + UIDevice.current.systemVersion)
            YInfoLine(title: "型号", value: UIDevice.current.model)
            YInfoLine(title: "标识", value: APIClient.shared.deviceID, monospaced: true)
        }.yCard(14)
    }

    private var storageCard: some View {
        VStack(spacing: 10) {
            YSectionTitle(title: "存储")
            YInfoLine(title: "总容量", value: bytes((FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemSize] as? NSNumber)?.int64Value))
            YInfoLine(title: "剩余", value: bytes((FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemFreeSize] as? NSNumber)?.int64Value))
            YInfoLine(title: "App 占用", value: bytes(folderSize(YFiles.root)))
        }.yCard(14)
    }

    private var appCard: some View {
        VStack(spacing: 10) {
            YSectionTitle(title: "App")
            YInfoLine(title: "版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
            YInfoLine(title: "构建", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
            YInfoLine(title: "最低系统", value: "iOS 15.0")
            YInfoLine(title: "签名内核", value: "zsign (local)")
        }.yCard(14)
    }

    private func bytes(_ value: Int64?) -> String {
        guard let value else { return "—" }
        return ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    private func folderSize(_ url: URL) -> Int64 {
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        var total: Int64 = 0
        while let item = enumerator?.nextObject() as? URL {
            total += Int64((try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }
}

struct DeviceSecurityView: View {
    private let checks: [(String, String, Bool)] = [
        ("Cydia / Sileo", "/Applications/Cydia.app", FileManager.default.fileExists(atPath: "/Applications/Cydia.app")),
        ("SSH 服务", "/usr/sbin/sshd", FileManager.default.fileExists(atPath: "/usr/sbin/sshd")),
        ("Bash", "/bin/bash", FileManager.default.fileExists(atPath: "/bin/bash")),
        ("越狱文件", "/private/jailbreak.txt", FileManager.default.fileExists(atPath: "/private/jailbreak.txt")),
        ("Cydia URL", "cydia://", UIApplication.shared.canOpenURL(URL(string: "cydia://")!))
    ]

    var body: some View {
        ToolPage(title: "设备安全") {
            VStack(spacing: 10) {
                YSectionTitle(title: "越狱检测")
                ForEach(checks, id: \.0) { item in
                    HStack {
                        Image(systemName: item.2 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundColor(item.2 ? YTheme.orange : YTheme.green)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.0).font(.subheadline).foregroundColor(YTheme.text)
                            Text(item.1).font(.system(size: 9, design: .monospaced)).foregroundColor(YTheme.muted)
                        }
                        Spacer()
                        Text(item.2 ? "检测到" : "正常").font(.caption.weight(.semibold)).foregroundColor(item.2 ? YTheme.orange : YTheme.green)
                    }
                }
            }.yCard(14)
            VStack(alignment: .leading, spacing: 8) {
                YSectionTitle(title: "网络代理")
                let proxy = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any]
                YInfoLine(title: "HTTP 代理", value: (proxy?["HTTPProxy"] as? String) ?? "未检测到")
                YInfoLine(title: "HTTPS 代理", value: (proxy?["HTTPSProxy"] as? String) ?? "未检测到")
            }.yCard(14)
            Text("检测结果仅供参考，不能覆盖所有越狱方式。").font(.caption2).foregroundColor(YTheme.muted)
        }
    }
}

struct NetworkCheckView: View {
    @State private var status = "未检测"
    @State private var latency = "—"
    @State private var checking = false
    @State private var ip = "—"

    var body: some View {
        ToolPage(title: "网络检测") {
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(YTheme.softGradient).frame(width: 92, height: 92)
                    Image(systemName: status == "正常" ? "wifi" : "wifi.exclamationmark")
                        .font(.system(size: 31)).foregroundColor(status == "正常" ? YTheme.green : YTheme.orange)
                }
                Text(status).font(.headline).foregroundColor(YTheme.text)
                Text("服务端：sign.yixsc.cn").font(.caption).foregroundColor(YTheme.muted)
                YPrimaryButton(title: checking ? "检测中…" : "开始检测", icon: "bolt.fill", enabled: !checking) { check() }
            }
            .frame(maxWidth: .infinity).padding(20).yCard(0)

            VStack(spacing: 10) {
                YInfoLine(title: "请求延迟", value: latency)
                YInfoLine(title: "本机 IP", value: ip)
                YInfoLine(title: "接口地址", value: "https://sign.yixsc.cn")
            }.yCard(14)
        }
        .onAppear { ip = Self.deviceIP() ?? "—" }
    }

    private func check() {
        checking = true
        let start = Date()
        var request = URLRequest(url: APIClient.baseURL.appendingPathComponent("api/health"))
        request.timeoutInterval = 15
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                checking = false
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    status = "正常"
                    latency = String(format: "%.0f ms", Date().timeIntervalSince(start) * 1000)
                } else {
                    status = "连接失败"
                    latency = error?.localizedDescription ?? "无响应"
                }
            }
        }.resume()
    }

    static func deviceIP() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            let interface = current.pointee
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var addr = interface.ifa_addr.pointee
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    return String(cString: hostname)
                }
            }
            pointer = interface.ifa_next
        }
        return nil
    }
}

struct IPAInspectView: View {
    @State private var showImporter = false
    @State private var name = "尚未选择 IPA"
    @State private var bundle = "—"
    @State private var version = "—"
    @State private var minOS = "—"
    @State private var size = "—"
    @State private var iconURL: URL?
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        ToolPage(title: "安装包分析") {
            VStack(spacing: 14) {
                if let iconURL {
                    YRemoteIcon(url: iconURL, fallback: name, size: 82)
                } else {
                    Image(systemName: "shippingbox.fill").font(.system(size: 34)).foregroundColor(YTheme.purple)
                        .frame(width: 82, height: 82).background(YTheme.softGradient).clipShape(RoundedRectangle(cornerRadius: 18))
                }
                Text(name).font(.headline).foregroundColor(YTheme.text)
                Text(bundle).font(.system(size: 10, design: .monospaced)).foregroundColor(YTheme.muted).lineLimit(1)
                YPrimaryButton(title: busy ? "解析中…" : "选择 IPA 文件", icon: "doc.badge.plus", enabled: !busy) { showImporter = true }
            }
            .frame(maxWidth: .infinity).padding(20).yCard(0)

            VStack(spacing: 10) {
                YInfoLine(title: "版本", value: version)
                YInfoLine(title: "最低系统", value: minOS)
                YInfoLine(title: "文件大小", value: size)
            }.yCard(14)
            if let error { Text(error).font(.caption).foregroundColor(YTheme.red) }
            Text("解析在本机完成，不会上传 IPA。").font(.caption2).foregroundColor(YTheme.muted)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { inspect(url) }
        }
    }

    private func inspect(_ url: URL) {
        busy = true; error = nil
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let work = YFiles.cache.appendingPathComponent("inspect-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: work) }
                try FileManager.default.unzipItem(at: url, to: work)
                guard let app = try FileManager.default.contentsOfDirectory(at: work, includingPropertiesForKeys: nil).first(where: { $0.pathExtension == "app" }) else {
                    throw APIError(message: "IPA 中没有 .app")
                }
                let plist = try AppModel.infoPlist(app)
                let icon = try? AppModel.copyIcon(from: app, to: work)
                let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                let n = plist["CFBundleDisplayName"] as? String ?? plist["CFBundleName"] as? String ?? app.lastPathComponent
                let b = plist["CFBundleIdentifier"] as? String ?? "—"
                let v = plist["CFBundleShortVersionString"] as? String ?? "—"
                let m = plist["MinimumOSVersion"] as? String ?? "—"
                let s = ByteCountFormatter.string(fromByteCount: Int64(attrs[.size] as? UInt64 ?? 0), countStyle: .file)
                DispatchQueue.main.async {
                    name = n; bundle = b; version = v; minOS = m; size = s; iconURL = icon; busy = false
                }
            } catch {
                DispatchQueue.main.async { self.error = error.localizedDescription; busy = false }
            }
        }
    }
}

struct CertificateCheckView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showCertificates = false

    var body: some View {
        ToolPage(title: "证书检测") {
            VStack(spacing: 10) {
                YSectionTitle(title: "本机证书", trailing: "\(model.certificates.count) 张")
                if model.certificates.isEmpty {
                    Text("还没有导入证书").font(.caption).foregroundColor(YTheme.muted)
                } else {
                    ForEach(model.certificates) { cert in
                        HStack(spacing: 10) {
                            Image(systemName: cert.isExpired ? "xmark.seal.fill" : "checkmark.seal.fill")
                                .foregroundColor(cert.isExpired ? YTheme.red : YTheme.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cert.name).font(.subheadline).foregroundColor(YTheme.text)
                                Text("到期 \(cert.expirationText) · \(cert.teamName)").font(.system(size: 9)).foregroundColor(YTheme.muted).lineLimit(1)
                            }
                            Spacer()
                            Text(cert.isExpired ? "已过期" : "有效").font(.caption2.weight(.semibold)).foregroundColor(cert.isExpired ? YTheme.red : YTheme.green)
                        }
                    }
                }
            }.yCard(14)
            YSecondaryButton(title: "管理证书", icon: "seal") { showCertificates = true }
            Text("证书状态以本机描述文件到期日为准，不代表 Apple 开发者账号状态。").font(.caption2).foregroundColor(YTheme.muted)
        }
        .sheet(isPresented: $showCertificates) { CertificatesView().environmentObject(model) }
    }
}

struct CacheCleanView: View {
    @State private var size: Int64 = 0
    @State private var cleared = false

    var body: some View {
        ToolPage(title: "缓存清理") {
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(YTheme.softGradient).frame(width: 100, height: 100)
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .font(.system(size: 18, weight: .bold)).foregroundColor(YTheme.purple)
                }
                Text("临时缓存").font(.headline).foregroundColor(YTheme.text)
                Text("解析临时文件、网络缓存与安装临时文件").font(.caption).foregroundColor(YTheme.muted)
                YPrimaryButton(title: cleared ? "已清理" : "清理缓存", icon: "trash.fill", enabled: !cleared) { clear() }
            }.frame(maxWidth: .infinity).padding(20).yCard(0)
            Text("不会删除证书、已签名 IPA 或用户文件。").font(.caption2).foregroundColor(YTheme.muted)
        }
        .onAppear { size = folderSize(YFiles.cache) }
    }

    private func clear() {
        try? FileManager.default.removeItem(at: YFiles.cache)
        try? FileManager.default.createDirectory(at: YFiles.cache, withIntermediateDirectories: true)
        URLCache.shared.removeAllCachedResponses()
        size = 0; cleared = true
    }

    private func folderSize(_ url: URL) -> Int64 {
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        var total: Int64 = 0
        while let item = enumerator?.nextObject() as? URL {
            total += Int64((try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }
}

struct UDIDView: View {
    @EnvironmentObject private var model: AppModel
    @State private var registered = "尚未登记"

    var body: some View {
        ToolPage(title: "UDID 获取") {
            VStack(alignment: .leading, spacing: 12) {
                YSectionTitle(title: "通过描述文件登记")
                Text("点击下方按钮，Safari 会安装一个配置描述文件。安装后服务端会收到设备的真实 UDID，并绑定到当前设备记录。")
                    .font(.caption).foregroundColor(YTheme.muted).lineSpacing(3)
                YPrimaryButton(title: "打开 UDID 登记页", icon: "safari.fill") {
                    let url = "https://sign.yixsc.cn/api/udid/profile?device=\(APIClient.shared.deviceID)"
                    if let target = URL(string: url) { UIApplication.shared.open(target, options: [:], completionHandler: nil) }
                }
                YSecondaryButton(title: "我已安装，查询 UDID", icon: "arrow.clockwise") { query() }
                Text(registered).font(.system(size: 11, design: .monospaced)).foregroundColor(YTheme.text).textSelection(.enabled)
            }.yCard(16)
            VStack(alignment: .leading, spacing: 8) {
                YSectionTitle(title: "说明")
                Text("• 需要 iOS 15 及以上，Safari 中安装描述文件后返回本 App。\n• UDID 仅用于证书注册与设备管理，不上传到第三方。\n• 如果查询不到，请先在系统设置中确认描述文件已安装。")
                    .font(.caption2).foregroundColor(YTheme.muted).lineSpacing(4)
            }.yCard(14)
        }
    }

    private func query() {
        var request = URLRequest(url: APIClient.baseURL.appendingPathComponent("api/udid/status"))
        request.setValue(APIClient.shared.deviceID, forHTTPHeaderField: "X-Device-ID")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            DispatchQueue.main.async {
                registered = json["udid"] as? String ?? "服务端尚未收到 UDID"
            }
        }.resume()
    }
}

struct DistributeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selected: SignedApp?
    @State private var busy = false
    @State private var installURL: String?
    @State private var error: String?

    var body: some View {
        ToolPage(title: "二维码分发") {
            VStack(alignment: .leading, spacing: 10) {
                YSectionTitle(title: "选择已签名应用")
                if model.signed.isEmpty {
                    Text("还没有已签名应用").font(.caption).foregroundColor(YTheme.muted)
                } else {
                    Menu {
                        ForEach(model.signed) { app in
                            Button(app.name) { selected = app }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.seal.fill").foregroundColor(YTheme.purple)
                            Text(selected?.name ?? "选择应用").font(.subheadline).foregroundColor(YTheme.text)
                            Spacer()
                            Image(systemName: "chevron.down").foregroundColor(YTheme.muted)
                        }
                        .padding(12).background(YTheme.background).clipShape(RoundedRectangle(cornerRadius: 11))
                    }
                }
                YPrimaryButton(title: busy ? "上传中…" : "生成分发链接", icon: "qrcode", enabled: !busy && selected != nil) { upload() }
                if let error { Text(error).font(.caption).foregroundColor(YTheme.red) }
            }.yCard(14)

            if let installURL {
                VStack(spacing: 12) {
                    if let image = Self.qr(installURL) {
                        Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(width: 190, height: 190)
                    }
                    Text(installURL).font(.system(size: 9, design: .monospaced)).foregroundColor(YTheme.muted).lineLimit(2)
                    HStack(spacing: 10) {
                        YSecondaryButton(title: "复制链接", icon: "doc.on.doc") { UIPasteboard.general.string = installURL }
                        YSecondaryButton(title: "打开安装页", icon: "safari") {
                            if let url = URL(string: installURL) { UIApplication.shared.open(url, options: [:], completionHandler: nil) }
                        }
                    }
                }
                .frame(maxWidth: .infinity).padding(18).yCard(0)
            }
        }
    }

    private func upload() {
        guard let selected else { return }
        busy = true; error = nil
        APIClient.shared.uploadInstall(ipaURL: URL(fileURLWithPath: selected.ipaPath), app: selected) { result in
            busy = false
            switch result {
            case .success(let value):
                if let page = value.pageURL { installURL = page }
                else if let manifest = value.manifestURL { installURL = manifest }
                else { error = value.message ?? "上传失败" }
            case .failure(let error): self.error = error.localizedDescription
            }
        }
    }

    static func qr(_ string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct SigningEnvironmentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ToolPage(title: "签名环境") {
            VStack(spacing: 10) {
                checkRow("zsign 内核", "已内置", true)
                checkRow("ZIPFoundation", "已内置", true)
                checkRow("证书数量", "\(model.certificates.count) 张", !model.certificates.isEmpty)
                checkRow("iOS 版本", UIDevice.current.systemVersion, ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 15)
                checkRow("服务端", model.config != nil ? "已连接" : "未连接", model.config != nil)
                checkRow("账号", model.isLoggedIn ? "已登录" : "未登录", model.isLoggedIn)
            }.yCard(14)
            Text("签名在设备本地完成，依赖开源 zsign 内核和本机证书。服务端只负责配置下发与安装包临时分发。")
                .font(.caption2).foregroundColor(YTheme.muted)
        }
    }

    private func checkRow(_ title: String, _ value: String, _ ok: Bool) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(ok ? YTheme.green : YTheme.orange)
            Text(title).font(.subheadline).foregroundColor(YTheme.text)
            Spacer()
            Text(value).font(.caption).foregroundColor(ok ? YTheme.green : YTheme.orange)
        }
    }
}

struct FileExportView: View {
    @State private var showShare = false
    var body: some View {
        ToolPage(title: "文件导出") {
            VStack(spacing: 14) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 34)).foregroundColor(YTheme.purple)
                    .frame(width: 88, height: 88).background(YTheme.softGradient).clipShape(Circle())
                Text("导出 App 沙盒文件").font(.headline).foregroundColor(YTheme.text)
                Text("分享已签名 IPA、证书目录或整个 YixiangPro 文件夹。").font(.caption).foregroundColor(YTheme.muted).multilineTextAlignment(.center)
                YPrimaryButton(title: "分享 YixiangPro 文件夹", icon: "folder.fill") { showShare = true }
            }.frame(maxWidth: .infinity).padding(20).yCard(0)
        }
        .sheet(isPresented: $showShare) { ShareSheet(items: [YFiles.root]) }
    }
}
