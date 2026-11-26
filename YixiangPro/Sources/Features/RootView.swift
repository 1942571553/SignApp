import SwiftUI

enum YTab: Int, CaseIterable {
    case apps, signed, files, downloads, tools, settings

    var title: String {
        switch self {
        case .apps: return "应用源"
        case .signed: return "已签名"
        case .files: return "文件"
        case .downloads: return "下载"
        case .tools: return "工具"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .apps: return "shippingbox.fill"
        case .signed: return "checkmark.seal.fill"
        case .files: return "folder.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selected: YTab = .apps
    @State private var showAccount = false

    var body: some View {
        ZStack(alignment: .bottom) {
            YTheme.homeBackground.ignoresSafeArea()
            Group {
                switch selected {
                case .apps: StoreView()
                case .signed: SignedAppsView()
                case .files: FilesView()
                case .downloads: DownloadsView()
                case .tools: ToolsView()
                case .settings: SettingsView()
                }
            }
            .padding(.bottom, 82)

            tabBar

            if model.isGloballyLocked {
                lockOverlay
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $showAccount) { AccountView() }
        .onOpenURL { model.handleDeepLink($0) }
        .onChange(of: model.requestedTab) { tab in
            guard let tab = tab, let target = YTab(rawValue: ["apps": 0, "signed": 1, "files": 2, "downloads": 3, "tools": 4, "settings": 5][tab] ?? 0) else { return }
            selected = target
            model.requestedTab = nil
        }
        .onChange(of: model.requestedAccount) { value in
            if value { showAccount = true; model.requestedAccount = false }
        }
    }

    private var lockOverlay: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()
            VStack(spacing: 13) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(YTheme.purple)
                Text("当前不可用").font(.system(size: 20, weight: .bold)).foregroundColor(YTheme.text)
                Text(model.globalLock?.reason ?? "服务端已开启时间锁，请在开放时间后再试。")
                    .font(.caption).foregroundColor(YTheme.muted)
                    .multilineTextAlignment(.center)
                YPrimaryButton(title: "重新检测", icon: "arrow.clockwise", enabled: true) {
                    model.refreshConfig()
                }
            }
            .padding(24)
            .frame(maxWidth: 300)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 24, y: 10)
            .padding(28)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(YTab.allCases, id: \.rawValue) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 17, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 8.8, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(selected == tab ? YTheme.purple : YTheme.muted.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(selected == tab ? YTheme.purple.opacity(0.10) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }
}
