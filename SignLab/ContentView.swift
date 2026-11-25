import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var ipaFile: UTType { UTType(filenameExtension: "ipa") ?? .data }
    static var p12File: UTType { UTType(filenameExtension: "p12") ?? .data }
    static var provFile: UTType { UTType(filenameExtension: "mobileprovision") ?? .data }
}

struct ContentView: View {
    @State private var ipaURL: URL?
    @State private var p12URL: URL?
    @State private var provURL: URL?
    @State private var password = ""
    @State private var bundleID = ""
    @State private var isSigning = false
    @State private var log = "选好 ipa、证书和描述文件，点开始签名。"
    @State private var signedURL: URL?
    @State private var showShare = false
    @State private var showAlert = false
    @State private var alertText = ""

    @State private var pickIPA = false
    @State private var pickP12 = false
    @State private var pickProv = false

    private var ready: Bool { ipaURL != nil && p12URL != nil && provURL != nil && !password.isEmpty }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.12, blue: 0.13).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    filesCard
                    certCard
                    actionCard
                    if signedURL != nil { resultCard }
                    Text("只签自己的 App、只用自己的证书。")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.top, 4)
                }
                .padding(18)
            }
        }
        .fileImporter(isPresented: $pickIPA, allowedContentTypes: [.ipaFile]) { result in
            if let url = try? result.get(), let stashed = stash(url) { ipaURL = stashed }
        }
        .fileImporter(isPresented: $pickP12, allowedContentTypes: [.p12File]) { result in
            if let url = try? result.get(), let stashed = stash(url) { p12URL = stashed }
        }
        .fileImporter(isPresented: $pickProv, allowedContentTypes: [.provFile, .data]) { result in
            if let url = try? result.get(), let stashed = stash(url) { provURL = stashed }
        }
        .sheet(isPresented: $showShare) {
            if let signedURL { ShareSheet(items: [signedURL]) }
        }
        .alert("提示", isPresented: $showAlert) { Button("好", role: .cancel) {} } message: { Text(alertText) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("签名工坊").font(.largeTitle.bold()).foregroundColor(.white)
            Text("在手机上离线重签，证书不出设备").font(.subheadline).foregroundColor(.teal.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var filesCard: some View {
        card {
            row(title: "IPA 安装包", value: ipaURL?.lastPathComponent) { pickIPA = true }
            divider
            row(title: "证书 .p12", value: p12URL?.lastPathComponent) { pickP12 = true }
            divider
            row(title: "描述文件", value: provURL?.lastPathComponent) { pickProv = true }
        }
    }

    private var certCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("p12 密码").font(.caption).foregroundColor(.white.opacity(0.55))
                SecureField("证书密码", text: $password)
                    .textContentType(.password)
                    .padding(12)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                Text("Bundle ID（留空保持原样）").font(.caption).foregroundColor(.white.opacity(0.55))
                TextField("com.example.app", text: $bundleID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(10)
                    .foregroundColor(.white)
            }
        }
    }

    private var actionCard: some View {
        card {
            VStack(spacing: 12) {
                Button(action: startSigning) {
                    HStack {
                        if isSigning { ProgressView().tint(.white) }
                        Text(isSigning ? "签名中…" : "开始签名").bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ready ? Color.teal : Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!ready || isSigning)

                Text(log)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var resultCard: some View {
        card {
            VStack(spacing: 10) {
                Text("签名完成").font(.headline).foregroundColor(.teal)
                Text(signedURL?.lastPathComponent ?? "")
                    .font(.footnote).foregroundColor(.white.opacity(0.7))
                Button {
                    install()
                } label: {
                    Text("安装到本机").bold().frame(maxWidth: .infinity).padding(.vertical, 13)
                }
                .background(Color.teal).foregroundColor(.white).cornerRadius(12)

                Button {
                    showShare = true
                } label: {
                    Text("分享 / 导出到文件").frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .background(Color.white.opacity(0.1)).foregroundColor(.white).cornerRadius(12)

                Text(Installer.detectTools().isEmpty
                     ? "未检测到越狱安装工具，可用 TrollStore 打开分享的文件安装。"
                     : "检测到安装工具：\(Installer.detectTools().joined(separator: ", "))")
                    .font(.caption2).foregroundColor(.white.opacity(0.45))
            }
        }
    }

    private func card<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.06))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1).padding(.vertical, 10)
    }

    private func row(title: String, value: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline).foregroundColor(.white)
                    Text(value ?? "未选择").font(.caption).foregroundColor(.white.opacity(0.5)).lineLimit(1)
                }
                Spacer()
                Image(systemName: "folder").foregroundColor(.teal)
            }
        }
    }

    private func stash(_ url: URL) -> URL? {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Input", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(String(UUID().uuidString.prefix(6)) + "-" + url.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            return dest
        } catch {
            return url
        }
    }

    private func startSigning() {
        guard let ipaURL, let p12URL, let provURL else { return }
        isSigning = true
        log = "准备签名…"
        let bundle = bundleID.trimmingCharacters(in: .whitespaces)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try SigningEngine.sign(
                    ipa: ipaURL,
                    p12: p12URL,
                    prov: provURL,
                    password: password,
                    bundleID: bundle.isEmpty ? nil : bundle
                )
                DispatchQueue.main.async {
                    signedURL = result.output
                    isSigning = false
                    log = "已生成：\(result.output.lastPathComponent)"
                }
            } catch {
                DispatchQueue.main.async {
                    isSigning = false
                    log = error.localizedDescription
                    alertText = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    private func install() {
        guard let signedURL else { return }
        log = "正在调用安装器…"
        DispatchQueue.main.async {
            let outcome = Installer.install(signedURL)
            log = outcome.message
            if !outcome.ok {
                alertText = outcome.message
                showAlert = true
            }
        }
    }
}
