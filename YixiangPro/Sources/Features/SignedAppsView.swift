import SwiftUI
import UIKit

struct SignedAppsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.presentationMode) private var presentation
    @State private var signTarget: ImportedApp?
    @State private var showCertificates = false
    @State private var shareFile: ShareFile?
    @State private var pendingDeleteImported: ImportedApp?
    @State private var pendingDeleteSigned: SignedApp?

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    if model.certificates.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(YTheme.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("还没有签名证书").font(.subheadline.weight(.semibold)).foregroundColor(YTheme.text)
                                Text("先导入 p12 与描述文件，才能签名").font(.caption).foregroundColor(YTheme.muted)
                            }
                            Spacer()
                            YSecondaryButton(title: "去导入", icon: "plus") { showCertificates = true }
                        }
                        .yCard(12)
                    }
                    pendingSection
                    signedSection
                }
                .padding(16)
                .padding(.bottom, 16)
            }
            .background(YTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(item: $signTarget) { app in
            SigningSheet(app: app)
                .environmentObject(model)
        }
        .sheet(isPresented: $showCertificates) { CertificatesView().environmentObject(model) }
        .sheet(item: $shareFile) { file in ShareSheet(items: [file.url]) }
        .confirmationDialog("删除这个待签名应用？", isPresented: Binding(get: { pendingDeleteImported != nil }, set: { if !$0 { pendingDeleteImported = nil } }), presenting: pendingDeleteImported) { app in
            Button("删除", role: .destructive) { model.deleteImported(app) }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("删除这个已签名应用？", isPresented: Binding(get: { pendingDeleteSigned != nil }, set: { if !$0 { pendingDeleteSigned = nil } }), presenting: pendingDeleteSigned) { app in
            Button("删除", role: .destructive) { model.deleteSigned(app) }
            Button("取消", role: .cancel) {}
        }
    }

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(YTheme.gradient)
            Circle().fill(Color.white.opacity(0.13)).frame(width: 140, height: 140).offset(x: 50, y: -60)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("已签名").font(.system(size: 26, weight: .heavy)).foregroundColor(.white)
                    Spacer()
                    Button { showCertificates = true } label: {
                        Image(systemName: "seal.fill").foregroundColor(.white).padding(9).background(Color.white.opacity(0.18)).clipShape(Circle())
                    }
                }
                Text("本地 zsign 内核 · 证书永不离开设备").font(.caption).foregroundColor(.white.opacity(0.78))
                HStack(spacing: 22) {
                    smallStat("\(model.imported.count)", "待签名")
                    smallStat("\(model.signed.count)", "已完成")
                    smallStat("\(model.certificates.count)", "证书")
                }
                .padding(.top, 6)
            }
            .padding(18)
        }
        .frame(height: 142)
        .clipped()
    }

    private func smallStat(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.headline).foregroundColor(.white)
            Text(title).font(.system(size: 9)).foregroundColor(.white.opacity(0.68))
        }
    }

    private var pendingSection: some View {
        VStack(spacing: 10) {
            YSectionTitle(title: "待签名", subtitle: "导入或下载的 IPA", trailing: "\(model.imported.count) 个")
            if model.imported.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "tray.and.arrow.down.fill").foregroundColor(YTheme.purple)
                    Text("在“应用”页下载，或从文件导入 IPA").font(.footnote).foregroundColor(YTheme.muted)
                    Spacer()
                }
                .yCard(12)
            } else {
                ForEach(model.imported) { app in
                    HStack(spacing: 12) {
                        YRemoteIcon(url: app.iconPath.map { URL(fileURLWithPath: $0) }, fallback: app.name, size: 50)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.name).font(.subheadline.weight(.semibold)).foregroundColor(YTheme.text).lineLimit(1)
                            Text("\(app.version) · \(app.bundleID)").font(.caption2).foregroundColor(YTheme.muted).lineLimit(1)
                        }
                        Spacer()
                        Button { signTarget = app } label: {
                            Text("签名").font(.caption.weight(.semibold)).foregroundColor(.white)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(YTheme.gradient).clipShape(Capsule())
                        }
                        Menu {
                            Button(role: .destructive) { pendingDeleteImported = app } label: { Label("删除", systemImage: "trash") }
                        } label: { Image(systemName: "ellipsis").foregroundColor(YTheme.muted) }
                    }
                    .yCard(10)
                }
            }
        }
    }

    private var signedSection: some View {
        VStack(spacing: 10) {
            YSectionTitle(title: "已签名应用", subtitle: "可安装 / 分享", trailing: "\(model.signed.count) 个")
            if model.signed.isEmpty {
                YEmpty(icon: "checkmark.seal", title: "还没有已签名应用", message: "选择一个待签名应用，配置名称和 Bundle ID 后开始签名。")
            } else {
                ForEach(model.signed) { app in
                    NavigationLink(destination: SignedDetailView(app: app)) {
                        HStack(spacing: 12) {
                            YRemoteIcon(url: app.iconPath.map { URL(fileURLWithPath: $0) }, fallback: app.name, size: 50)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.name).font(.subheadline.weight(.semibold)).foregroundColor(YTheme.text).lineLimit(1)
                                Text("\(app.version) · \(app.bundleID)").font(.caption2).foregroundColor(YTheme.muted).lineLimit(1)
                                Text("签名证书：\(app.certificateName)").font(.system(size: 9)).foregroundColor(YTheme.green).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(YTheme.muted)
                        }
                        .yCard(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

struct SignedDetailView: View {
    @EnvironmentObject private var model: AppModel
    let app: SignedApp
    @State private var busy = false
    @State private var error: String?
    @State private var showShare = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    YRemoteIcon(url: app.iconPath.map { URL(fileURLWithPath: $0) }, fallback: app.name, size: 92)
                    Text(app.name).font(.system(size: 22, weight: .bold)).foregroundColor(YTheme.text)
                    Text("已签名 · \(app.certificateName)").font(.caption).foregroundColor(YTheme.green)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 22)
                .background(YTheme.softGradient).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(spacing: 10) {
                    YInfoLine(title: "Bundle ID", value: app.bundleID, monospaced: true)
                    YInfoLine(title: "版本", value: app.version)
                    YInfoLine(title: "签名时间", value: app.signedAt.formatted(date: .numeric, time: .shortened))
                    YInfoLine(title: "安装地址", value: app.installURL ?? "上传后生成")
                }
                .yCard(14)

                VStack(spacing: 10) {
                    YPrimaryButton(title: busy ? "正在上传安装包…" : "安装到设备", icon: "arrow.down.app.fill", enabled: !busy) {
                        install()
                    }
                    HStack(spacing: 10) {
                        YSecondaryButton(title: "分享 IPA", icon: "square.and.arrow.up", color: YTheme.blue) { showShare = true }
                        YSecondaryButton(title: "复制安装地址", icon: "link", color: YTheme.violet) {
                            UIPasteboard.general.string = app.installURL
                            model.message = "已复制"
                        }
                    }
                }
                Text("安装会先把签名后的 IPA 上传到服务端临时目录，再通过 itms-services 安装。上传文件会在服务端自动过期清理。")
                    .font(.caption2).foregroundColor(YTheme.muted).multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(16)
        }
        .background(YTheme.background.ignoresSafeArea())
        .navigationTitle("已签名应用")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .sheet(isPresented: $showShare) { ShareSheet(items: [URL(fileURLWithPath: app.ipaPath)]) }
        .alert("提示", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("好", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private func install() {
        busy = true
        model.install(app) { ok, message in
            busy = false
            if !ok { error = message ?? "安装失败" }
        }
    }
}

struct ShareFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SigningSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.presentationMode) private var presentation
    let app: ImportedApp
    @State private var name: String
    @State private var bundleID: String
    @State private var version: String
    @State private var certID: String
    @State private var busy = false
    @State private var error: String?
    @State private var done = false
    @State private var minOS = ""
    @State private var removePlugIns = false
    @State private var removeWatch = false
    @State private var dylibURL: URL?
    @State private var showDylibPicker = false

    init(app: ImportedApp) {
        self.app = app
        _name = State(initialValue: app.name)
        _bundleID = State(initialValue: app.bundleID)
        _version = State(initialValue: app.version)
        _certID = State(initialValue: "")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 12) {
                        YRemoteIcon(url: app.iconPath.map { URL(fileURLWithPath: $0) }, fallback: app.name, size: 62)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.name).font(.headline).foregroundColor(YTheme.text)
                            Text("原始版本 \(app.version) · 最低 iOS \(app.minOS)").font(.caption).foregroundColor(YTheme.muted)
                        }
                        Spacer()
                    }
                    .yCard(14)

                    VStack(alignment: .leading, spacing: 12) {
                        YSectionTitle(title: "签名信息")
                        input("应用名称", $name)
                        input("Bundle ID", $bundleID)
                        input("版本号", $version)
                    }
                    .yCard(14)

                    VStack(alignment: .leading, spacing: 10) {
                        YSectionTitle(title: "签名证书")
                        if model.certificates.isEmpty {
                            HStack {
                                Text("没有可用证书").font(.caption).foregroundColor(YTheme.red)
                                Spacer()
                                YSecondaryButton(title: "去证书管理", icon: "plus") { error = "请先关闭本页，在证书管理中导入" }
                            }
                        } else {
                            Menu {
                                ForEach(model.certificates) { cert in
                                    Button {
                                        certID = cert.id
                                    } label: {
                                        Label("\(cert.name) · \(cert.expirationText)", systemImage: certID == cert.id ? "checkmark" : "seal")
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "seal.fill").foregroundColor(YTheme.purple)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(selectedCert?.name ?? "选择证书").font(.subheadline).foregroundColor(YTheme.text)
                                        Text(selectedCert.map { "到期 \($0.expirationText)" } ?? "").font(.caption2).foregroundColor(YTheme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.down").font(.caption).foregroundColor(YTheme.muted)
                                }
                                .padding(12).background(YTheme.background).clipShape(RoundedRectangle(cornerRadius: 11))
                            }
                        }
                    }
                    .yCard(14)

                    VStack(alignment: .leading, spacing: 10) {
                        YSectionTitle(title: "高级补丁", subtitle: "可选")
                        input("最低系统版本（留空不改）", $minOS)
                        Toggle("删除 PlugIns（插件）", isOn: $removePlugIns).font(.caption).tint(YTheme.purple)
                        Toggle("删除 Watch（手表 App）", isOn: $removeWatch).font(.caption).tint(YTheme.purple)
                        Button { showDylibPicker = true } label: {
                            HStack {
                                Image(systemName: "syringe.fill").foregroundColor(YTheme.violet)
                                Text(dylibURL?.lastPathComponent ?? "注入 Dylib（可选）").font(.caption).foregroundColor(dylibURL == nil ? YTheme.muted : YTheme.text)
                                Spacer()
                                if dylibURL != nil { Button { dylibURL = nil } label: { Image(systemName: "xmark.circle.fill").foregroundColor(YTheme.muted) } }
                            }
                            .padding(10).background(YTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(PlainButtonStyle())
                    }
                    .yCard(14)

                    if let error { Text(error).font(.caption).foregroundColor(YTheme.red).multilineTextAlignment(.center) }
                    YPrimaryButton(title: busy ? "正在签名…" : "开始签名", icon: "signature", enabled: !busy && selectedCert != nil) {
                        sign()
                    }
                    Text("签名过程完全在本机完成，使用开源 zsign 内核；不会把 p12 或描述文件上传到服务器。")
                        .font(.caption2).foregroundColor(YTheme.muted).multilineTextAlignment(.center)
                }
                .padding(16)
            }
            .background(YTheme.background.ignoresSafeArea())
            .navigationTitle("签名配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("取消") { presentation.wrappedValue.dismiss() } }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            if certID.isEmpty { certID = model.defaultCertificate()?.id ?? "" }
        }
        .fileImporter(isPresented: $showDylibPicker, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result { dylibURL = urls.first }
        }
    }

    private var selectedCert: CertificateRecord? {
        model.certificates.first(where: { $0.id == certID })
    }

    private func input(_ title: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundColor(YTheme.muted)
            TextField(title, text: binding)
                .font(.system(size: 13))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(10).background(YTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func sign() {
        guard let cert = selectedCert else { return }
        busy = true
        error = nil
        model.sign(app, certificate: cert, options: SignOptions(name: name, bundleID: bundleID, version: version, minOS: minOS, removePlugIns: removePlugIns, removeWatch: removeWatch, injectDylibPath: dylibURL?.path)) { ok, message in
            busy = false
            if ok {
                done = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { presentation.wrappedValue.dismiss() }
            } else {
                error = message ?? "签名失败"
            }
        }
    }
}
