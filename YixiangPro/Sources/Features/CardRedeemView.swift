import SwiftUI

struct CardRedeemView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.presentationMode) private var presentation
    let source: RemoteSource
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?
    @State private var success: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 10) {
                        YRemoteIcon(url: source.iconLink, fallback: source.name, size: 64)
                        Text(source.name).font(.system(size: 21, weight: .bold)).foregroundColor(YTheme.text)
                        Text(source.description ?? "该软件源需要卡密解锁后使用")
                            .font(.caption).foregroundColor(YTheme.muted).multilineTextAlignment(.center)
                        if let price = source.price, !price.isEmpty {
                            Text("解锁价格：\(price)").font(.caption.weight(.semibold)).foregroundColor(YTheme.purple)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(YTheme.softGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    if !model.isLoggedIn {
                        VStack(spacing: 10) {
                            Text("请先登录账号").font(.headline).foregroundColor(YTheme.text)
                            Text("卡密会绑定到账号与设备，登录后才能兑换。").font(.caption).foregroundColor(YTheme.muted)
                            Button("去登录") { presentation.wrappedValue.dismiss() }
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20).padding(.vertical, 10)
                                .background(YTheme.gradient).clipShape(Capsule())
                        }
                        .yCard(18)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            YSectionTitle(title: "输入解锁卡密")
                            HStack(spacing: 10) {
                                Image(systemName: "key.fill").foregroundColor(YTheme.purple)
                                TextField("例如 YX-ABCD-EFGH", text: $code)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled(true)
                            }
                            .padding(13)
                            .background(YTheme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            if let error {
                                Text(error).font(.caption).foregroundColor(YTheme.red)
                            }
                            if let success {
                                Label(success, systemImage: "checkmark.circle.fill")
                                    .font(.caption).foregroundColor(YTheme.green)
                            }
                            Button {
                                redeem()
                            } label: {
                                HStack {
                                    if busy { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                                    Text("立即解锁")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(YTheme.gradient)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .disabled(busy || code.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .yCard(16)
                    }

                    Text("卡密由服务端后台生成，可设置有效天数、可绑定设备数量，并记录每次兑换。")
                        .font(.caption2).foregroundColor(YTheme.muted).multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(16)
            }
            .background(YTheme.background.ignoresSafeArea())
            .navigationTitle("软件源解锁")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { presentation.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func redeem() {
        busy = true
        error = nil
        model.redeem(code: code.trimmingCharacters(in: .whitespacesAndNewlines)) { ok, message in
            busy = false
            if ok {
                success = message ?? "解锁成功"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    presentation.wrappedValue.dismiss()
                }
            } else {
                error = message ?? "卡密无效"
            }
        }
    }
}
