import UIKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showAccount = false
    @State private var showCertificates = false
    @State private var redeemSource: RemoteSource?
    @State private var updateMessage: String?

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    profileCard
                    licenseCard
                    accountSection
                    sourceSection
                    serverSection
                    aboutSection
                    footer
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(YTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showAccount) { AccountView().environmentObject(model) }
        .sheet(isPresented: $showCertificates) { CertificatesView().environmentObject(model) }
        .sheet(item: $redeemSource) { source in CardRedeemView(source: source).environmentObject(model) }
        .alert("提示", isPresented: Binding(get: { updateMessage != nil }, set: { if !$0 { updateMessage = nil } })) {
            Button("好", role: .cancel) {}
        } message: { Text(updateMessage ?? "") }
    }

    private var profileCard: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(YTheme.gradient)
            Circle().fill(Color.white.opacity(0.14)).frame(width: 150, height: 150).offset(x: 55, y: -60)
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.18)).frame(width: 64, height: 64)
                    Image(systemName: "person.fill").font(.system(size: 27)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.user?.username ?? "未登录")
                        .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                    Text(model.user == nil ? "登录后可同步授权与卡密" : "ID \(model.user?.id ?? 0) · \(model.user?.role == "admin" ? "管理员" : "普通用户")")
                        .font(.caption).foregroundColor(.white.opacity(0.78))
                }
                Spacer()
                Button { showAccount = true } label: {
                    Text(model.isLoggedIn ? "账号" : "登录")
                        .font(.caption.weight(.semibold)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.white.opacity(0.18)).clipShape(Capsule())
                }
            }
            .padding(18)
        }
        .frame(height: 122)
        .clipped()
    }

    private var licenseCard: some View {
        HStack(spacing: 12) {
            Image(systemName: model.isGloballyLocked ? "lock.shield.fill" : "shield.checkered")
                .font(.system(size: 24)).foregroundColor(model.isGloballyLocked ? YTheme.orange : YTheme.green)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.isGloballyLocked ? "服务端时间锁已开启" : "服务端状态正常")
                    .font(.subheadline.weight(.semibold)).foregroundColor(YTheme.text)
                Text(licenseDetail).font(.caption).foregroundColor(YTheme.muted)
            }
            Spacer()
            if let days = model.remainingDays {
                Text("\(days) 天").font(.system(size: 17, weight: .bold)).foregroundColor(days > 0 ? YTheme.purple : YTheme.red)
            }
        }.yCard(13)
    }

    private var licenseDetail: String {
        if model.isGloballyLocked { return model.globalLock?.reason ?? "当前 App 受服务端时间限制" }
        if let days = model.remainingDays { return days > 0 ? "账号授权剩余 \(days) 天" : "账号授权已到期，请联系管理员" }
        return "服务端配置已连接 · 数据由后台统一管理"
    }

    private var accountSection: some View {
        VStack(spacing: 0) {
            sectionTitle("账号与授权")
            settingRow(icon: "person.crop.circle.fill", color: YTheme.purple, title: "账号中心", subtitle: model.user?.username ?? "登录 / 注册") { showAccount = true }
            divider
            settingRow(icon: "checkmark.seal.fill", color: YTheme.green, title: "证书管理", subtitle: "\(model.certificates.count) 张本地证书") { showCertificates = true }
            divider
            settingRow(icon: "key.fill", color: YTheme.orange, title: "软件源卡密", subtitle: "在锁定的软件源中兑换") { redeemSource = model.sources.first(where: { $0.requiresCard && !$0.unlocked }) }
        }
    }

    private var sourceSection: some View {
        VStack(spacing: 0) {
            sectionTitle("默认软件源")
            if model.sources.isEmpty {
                HStack {
                    Text("服务端尚未配置软件源").font(.caption).foregroundColor(YTheme.muted)
                    Spacer()
                    Button("刷新") { model.refreshConfig() }.font(.caption).foregroundColor(YTheme.purple)
                }.padding(14)
            } else {
                ForEach(model.sources) { source in
                    Button {
                        if source.lockReason != nil { redeemSource = source }
                    } label: {
                        HStack(spacing: 10) {
                            YRemoteIcon(url: source.iconLink, fallback: source.name, size: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.name).font(.subheadline).foregroundColor(YTheme.text)
                                Text(source.lockReason ?? "已启用 · 服务端下发").font(.caption2).foregroundColor(source.lockReason == nil ? YTheme.green : YTheme.orange)
                            }
                            Spacer()
                            if source.lockReason != nil { Image(systemName: "lock.fill").font(.caption).foregroundColor(YTheme.orange) }
                        }
                        .padding(14)
                    }.buttonStyle(PlainButtonStyle())
                    if source.id != model.sources.last?.id { divider }
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: YTheme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: YTheme.radius, style: .continuous).stroke(YTheme.border, lineWidth: 0.8))
    }

    private var serverSection: some View {
        VStack(spacing: 0) {
            sectionTitle("服务端")
            HStack {
                settingIcon("server.rack", YTheme.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("服务器地址").font(.subheadline).foregroundColor(YTheme.text)
                    Text("https://sign.yixsc.cn").font(.system(size: 9.5, design: .monospaced)).foregroundColor(YTheme.muted)
                }
                Spacer()
                Text(model.config == nil ? "未连接" : "已连接")
                    .font(.caption2.weight(.semibold)).foregroundColor(model.config == nil ? YTheme.red : YTheme.green)
            }.padding(14)
            divider
            HStack {
                settingIcon("clock.arrow.circlepath", YTheme.violet)
                VStack(alignment: .leading, spacing: 2) {
                    Text("配置同步").font(.subheadline).foregroundColor(YTheme.text)
                    Text(model.lastSync.map { "上次同步：" + $0.formatted(date: .numeric, time: .shortened) } ?? "尚未同步").font(.caption2).foregroundColor(YTheme.muted)
                }
                Spacer()
                Button("刷新") { model.refreshConfig() }.font(.caption.weight(.semibold)).foregroundColor(YTheme.purple)
            }.padding(14)
            if let announcement = model.announcement, !announcement.isEmpty {
                divider
                HStack(alignment: .top, spacing: 10) {
                    settingIcon("megaphone.fill", YTheme.orange)
                    Text(announcement).font(.caption).foregroundColor(YTheme.text).lineSpacing(2)
                }.padding(14)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: YTheme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: YTheme.radius, style: .continuous).stroke(YTheme.border, lineWidth: 0.8))
    }

    private var aboutSection: some View {
        VStack(spacing: 0) {
            sectionTitle("关于")
            settingRow(icon: "info.circle.fill", color: YTheme.blue, title: "版本", subtitle: "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0") · iOS 15+") { updateMessage = nil }
            divider
            settingRow(icon: "arrow.triangle.2.circlepath", color: YTheme.purple, title: "检查更新", subtitle: "从服务端获取版本策略") { checkUpdate() }
            divider
            settingRow(icon: "doc.text.fill", color: YTheme.muted, title: "开源组件", subtitle: "zsign · ZIPFoundation") { updateMessage = "签名内核 zsign，压缩库 ZIPFoundation，均为开源组件。" }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        HStack {
            Text(text).font(.caption.weight(.semibold)).foregroundColor(YTheme.muted)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.top, 13).padding(.bottom, 4)
    }

    private func settingRow(icon: String, color: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                settingIcon(icon, color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline).foregroundColor(YTheme.text)
                    Text(subtitle).font(.caption2).foregroundColor(YTheme.muted).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundColor(YTheme.muted.opacity(0.55))
            }.padding(14)
        }.buttonStyle(PlainButtonStyle())
    }

    private func settingIcon(_ icon: String, _ color: Color) -> some View {
        Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundColor(color)
            .frame(width: 30, height: 30).background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var divider: some View { Divider().padding(.leading, 55) }

    private func checkUpdate() {
        if let urlString = model.config?.client?.downloadURL, let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else if model.config?.client?.forceUpdate == true {
            updateMessage = "服务端要求更新到 \(model.config?.client?.version ?? "最新版本")"
        } else {
            updateMessage = "当前已是最新版本 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0")"
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("艺祥签 · YixiangPro").font(.caption.weight(.semibold)).foregroundColor(YTheme.muted)
            Text("客户端与服务端完全重做 · 最低 iOS 15").font(.system(size: 9)).foregroundColor(YTheme.muted.opacity(0.8))
        }.padding(.top, 10)
    }
}
