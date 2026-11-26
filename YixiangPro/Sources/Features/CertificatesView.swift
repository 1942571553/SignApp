import SwiftUI
import UniformTypeIdentifiers

struct CertificatesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.presentationMode) private var presentation
    @State private var showImport = false
    @State private var deleteTarget: CertificateRecord?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    if model.certificates.isEmpty {
                        YEmpty(
                            icon: "checkmark.seal",
                            title: "还没有签名证书",
                            message: "导入 .p12 证书和 .mobileprovision 描述文件后即可开始签名。",
                            action: { showImport = true },
                            actionTitle: "导入证书"
                        )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(model.certificates) { cert in
                                certificateRow(cert)
                            }
                        }
                    }
                    Text("证书与密码只保存在本机 App 沙盒内，不会上传到服务端。签名在设备本地完成。")
                        .font(.caption2).foregroundColor(YTheme.muted).multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                }
                .padding(16)
            }
            .background(YTheme.background.ignoresSafeArea())
            .navigationTitle("证书管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { presentation.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showImport = true } label: { Image(systemName: "plus") }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showImport) { CertificateImportView() }
        .confirmationDialog("删除这张证书？", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { cert in
            Button("删除", role: .destructive) { model.deleteCertificate(cert) }
            Button("取消", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.white.opacity(0.18)).frame(width: 56, height: 56)
                Image(systemName: "checkmark.seal.fill").font(.system(size: 24)).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(model.certificates.count) 张可用证书").font(.headline).foregroundColor(.white)
                Text("本地签名 · 不上传证书").font(.caption).foregroundColor(.white.opacity(0.78))
            }
            Spacer()
        }
        .padding(18)
        .background(YTheme.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func certificateRow(_ cert: CertificateRecord) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(cert.isExpired ? YTheme.red.opacity(0.1) : YTheme.purple.opacity(0.1))
                Image(systemName: "seal.fill").foregroundColor(cert.isExpired ? YTheme.red : YTheme.purple)
            }
            .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(cert.name).font(.subheadline.weight(.semibold)).foregroundColor(YTheme.text).lineLimit(1)
                    if cert.isDefault { YSoftPill(title: "默认", color: YTheme.purple) }
                }
                Text(cert.teamName.isEmpty ? cert.expirationText : cert.teamName)
                    .font(.caption).foregroundColor(YTheme.muted).lineLimit(1)
                HStack(spacing: 8) {
                    Text("到期 \(cert.expirationText)")
                    Text(cert.isExpired ? "已过期" : "有效")
                }
                .font(.system(size: 9.5))
                .foregroundColor(cert.isExpired ? YTheme.red : YTheme.green)
            }
            Spacer(minLength: 0)
            Menu {
                Button {
                    for index in model.certificates.indices { model.certificates[index].isDefault = model.certificates[index].id == cert.id }
                    model.saveCertificates()
                } label: { Label("设为默认", systemImage: "star") }
                Button(role: .destructive) { deleteTarget = cert } label: { Label("删除", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis").foregroundColor(YTheme.muted).padding(8)
            }
        }
        .yCard(12)
    }
}

extension CertificateRecord {
    var isExpired: Bool { expiration < Date() }
    var expirationText: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: expiration)
    }
}

struct CertificateImportView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.presentationMode) private var presentation
    @State private var p12URL: URL?
    @State private var provisionURL: URL?
    @State private var password = ""
    @State private var nickname = ""
    @State private var showP12Picker = false
    @State private var showProvisionPicker = false
    @State private var busy = false
    @State private var error: String?

    private var p12Type: UTType { UTType(filenameExtension: "p12") ?? .data }
    private var provisionType: UTType { UTType(filenameExtension: "mobileprovision") ?? .data }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 28)).foregroundColor(YTheme.purple)
                            .frame(width: 68, height: 68).background(YTheme.softGradient).clipShape(Circle())
                        Text("导入签名证书").font(.headline).foregroundColor(YTheme.text)
                        Text("需要 .p12 证书与对应的 .mobileprovision 描述文件").font(.caption).foregroundColor(YTheme.muted)
                    }
                    .padding(.vertical, 10)

                    VStack(spacing: 10) {
                        fileButton(title: p12URL?.lastPathComponent ?? "选择 .p12 证书", icon: "doc.badge.plus", selected: p12URL != nil) {
                            showP12Picker = true
                        }
                        fileButton(title: provisionURL?.lastPathComponent ?? "选择 .mobileprovision", icon: "doc.text", selected: provisionURL != nil) {
                            showProvisionPicker = true
                        }
                    }
                    .yCard(14)

                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "key.fill").foregroundColor(YTheme.purple)
                            SecureField("P12 密码（没有可留空）", text: $password).font(.subheadline)
                        }
                        .padding(12).background(YTheme.background).clipShape(RoundedRectangle(cornerRadius: 11))
                        HStack {
                            Image(systemName: "tag.fill").foregroundColor(YTheme.purple)
                            TextField("证书备注名（可选）", text: $nickname).font(.subheadline)
                        }
                        .padding(12).background(YTheme.background).clipShape(RoundedRectangle(cornerRadius: 11))
                    }
                    .yCard(14)

                    if let error { Text(error).font(.caption).foregroundColor(YTheme.red).multilineTextAlignment(.center) }
                    YPrimaryButton(title: busy ? "正在导入…" : "导入证书", icon: "square.and.arrow.down", enabled: !busy && p12URL != nil && provisionURL != nil) {
                        importNow()
                    }
                }
                .padding(16)
            }
            .background(YTheme.background.ignoresSafeArea())
            .navigationTitle("添加证书")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("取消") { presentation.wrappedValue.dismiss() } }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fileImporter(isPresented: $showP12Picker, allowedContentTypes: [p12Type], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result { p12URL = urls.first }
        }
        .fileImporter(isPresented: $showProvisionPicker, allowedContentTypes: [provisionType], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result { provisionURL = urls.first }
        }
    }

    private func fileButton(title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundColor(selected ? YTheme.green : YTheme.purple).frame(width: 22)
                Text(title).font(.footnote).foregroundColor(selected ? YTheme.text : YTheme.muted).lineLimit(1)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundColor(selected ? YTheme.green : YTheme.muted)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func importNow() {
        guard let p12URL, let provisionURL else { return }
        busy = true
        error = nil
        DispatchQueue.global(qos: .userInitiated).async {
            CertificateManager.shared.importCertificate(p12URL: p12URL, provisionURL: provisionURL, password: password, nickname: nickname) { ok, message in
                DispatchQueue.main.async {
                    busy = false
                    if ok {
                        presentation.wrappedValue.dismiss()
                    } else {
                        error = message ?? "导入失败"
                    }
                }
            }
        }
    }
}
