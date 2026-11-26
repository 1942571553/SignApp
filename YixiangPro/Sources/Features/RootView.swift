import SwiftUI

enum YTab: Int, CaseIterable {
    case apps, signed, files, downloads, tools, settings

    var title: String {
        switch self {
        case .apps: return "应用"
        case .signed: return "已签名"
        case .files: return "文件"
        case .downloads: return "下载"
        case .tools: return "工具"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .apps: return "square.grid.2x2.fill"
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
            YTheme.background.ignoresSafeArea()
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
            .padding(.bottom, 62)

            tabBar
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

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(YTab.allCases, id: \.rawValue) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .foregroundColor(selected == tab ? YTheme.purple : YTheme.muted.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 9)
        .padding(.bottom, 8)
        .background(
            Color.white
                .overlay(Rectangle().fill(YTheme.border).frame(height: 0.6), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
