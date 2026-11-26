import SwiftUI
import Foundation

struct StoreView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @State private var category = "全部"
    @State private var showSearch = false
    @State private var showSources = false
    @State private var selectedSourceID: String?
    @State private var redeemSource: RemoteSource?

    private var selectedSource: RemoteSource? {
        if let id = selectedSourceID, let source = model.sources.first(where: { $0.id == id }) {
            return source
        }
        return model.sources.first
    }

    private var scopedApps: [StoreItem] {
        guard let source = selectedSource else { return model.apps }
        return model.apps.filter { $0.source.id == source.id }
    }

    private var categories: [String] {
        var values = ["全部", "未分类", "应用", "游戏", "影音", "工具", "插件"]
        let extra = Set(scopedApps.compactMap { item -> String? in
            let value = item.app.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? nil : value
        })
        values.append(contentsOf: extra.filter { !values.contains($0) }.sorted())
        return values
    }

    private var filtered: [StoreItem] {
        scopedApps.filter { item in
            let matchesQuery = query.isEmpty
                || item.app.displayName.localizedCaseInsensitiveContains(query)
                || item.app.summary.localizedCaseInsensitiveContains(query)
                || item.app.bundleID.localizedCaseInsensitiveContains(query)
            guard matchesQuery else { return false }
            guard category != "全部" else { return true }

            let rawCategory = item.app.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let lower = rawCategory.lowercased()
            let type = item.app.type?.value ?? ""

            switch category {
            case "未分类":
                return rawCategory.isEmpty
            case "应用":
                return rawCategory.isEmpty
                    || lower.contains("应用")
                    || lower.contains("utility")
                    || lower.contains("utilities")
            case "游戏":
                return lower.contains("游戏") || lower.contains("game")
            case "影音":
                return lower.contains("影音")
                    || lower.contains("视频")
                    || lower.contains("video")
                    || lower.contains("音乐")
                    || lower.contains("music")
                    || lower.contains("entertainment")
            case "工具":
                return lower.contains("工具")
                    || lower.contains("tool")
                    || lower.contains("utility")
                    || lower.contains("utilities")
            case "插件":
                return type == "1"
                    || lower.contains("插件")
                    || lower.contains("plugin")
            default:
                return rawCategory.localizedCaseInsensitiveContains(category)
            }
        }
    }

    private var recentCount: Int {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        return scopedApps.filter { item in
            guard let date = item.app.versionDate?.date else { return false }
            return date >= cutoff
        }.count
    }

    private var expiryDate: Date? {
        if let expires = selectedSource?.expiresAt, expires > 0 {
            return Date(timeIntervalSince1970: TimeInterval(expires))
        }
        if let expires = model.user?.expiresAt, expires > 0 {
            return Date(timeIntervalSince1970: TimeInterval(expires))
        }
        return nil
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    topBar

                    if showSearch {
                        searchBar
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    categoryBar
                    sourceCard

                    if let announcement = model.announcement, !announcement.isEmpty {
                        announcementCard(announcement)
                    }

                    if model.isGloballyLocked {
                        globalLockCard
                    }

                    if filtered.isEmpty {
                        YEmpty(
                            icon: "shippingbox",
                            title: model.isLoading ? "正在同步软件源" : "暂无应用",
                            message: model.isLoading ? "正在从服务端拉取应用数据…" : "当前软件源还没有应用，或者当前分类没有应用。",
                            action: { model.refreshStore() },
                            actionTitle: "重新加载"
                        )
                    } else {
                        appList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(YTheme.homeBackground.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showSources) {
            SourcePickerView(selectedSourceID: $selectedSourceID)
                .environmentObject(model)
        }
        .sheet(item: $redeemSource) { source in
            CardRedeemView(source: source)
                .environmentObject(model)
        }
        .onAppear {
            if selectedSourceID == nil {
                selectedSourceID = model.sources.first?.id
            }
        }
        .onChange(of: model.sources) { sources in
            if selectedSourceID == nil {
                selectedSourceID = sources.first?.id
            } else if let id = selectedSourceID, !sources.contains(where: { $0.id == id }) {
                selectedSourceID = sources.first?.id
            }
        }
        .onChange(of: selectedSourceID) { _ in
            category = "全部"
            query = ""
        }
        .overlay {
            if !model.allowStore {
                FeatureOffView(title: "软件源商店已关闭", message: "管理员已在服务端关闭软件源商店，可在设置中刷新配置或联系管理员。")
                    .background(YTheme.homeBackground)
            }
        }
    }

    // MARK: - 顶部导航

    private var topBar: some View {
        ZStack {
            Text("应用列表")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(YTheme.text)

            HStack(spacing: 8) {
                Button {
                    showSources = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("软件源")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(YTheme.purple)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.58))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.75), lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    topIconButton("magnifyingglass") {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showSearch.toggle()
                            if !showSearch { query = "" }
                        }
                    }
                    Rectangle()
                        .fill(YTheme.border.opacity(0.55))
                        .frame(width: 0.6, height: 18)
                    topIconButton("arrow.down.to.line") {
                        model.requestedTab = "downloads"
                    }
                }
                .padding(4)
                .background(Color.white.opacity(0.58))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.75), lineWidth: 1))
            }
        }
        .frame(height: 40)
    }

    private func topIconButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(YTheme.purple)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(YTheme.purple.opacity(0.8))
            TextField("搜索应用、Bundle ID", text: $query)
                .font(.subheadline)
                .foregroundColor(YTheme.text)
                .disableAutocorrection(true)
                .autocapitalization(.none)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(YTheme.muted)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showSearch = false
                    query = ""
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(YTheme.muted)
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(YTheme.glass)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        )
    }

    // MARK: - 分类

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { value in
                    Button { category = value } label: {
                        Text(value)
                            .font(.system(size: 12, weight: category == value ? .bold : .medium))
                            .foregroundColor(category == value ? .white : YTheme.muted)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(category == value
                                        ? AnyView(YTheme.gradient)
                                        : AnyView(Color.white.opacity(0.52)))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(category == value ? Color.clear : Color.white.opacity(0.6), lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .animation(.easeInOut(duration: 0.16), value: category)
                }
            }
            .padding(.vertical, 1)
        }
    }

    // MARK: - 源信息卡

    private var sourceCard: some View {
        VStack(spacing: 6) {
            Text(selectedSource?.name ?? "未配置软件源")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(YTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if selectedSource == nil {
                Text("管理员还没有配置默认软件源")
                    .font(.footnote)
                    .foregroundColor(YTheme.muted)
                    .padding(.bottom, 3)
            }

            sourceInfoLine("刷新时间", dateText(model.lastSync))
            sourceInfoLine("到期时间", dateText(expiryDate))
            sourceInfoLine("软件个数", "\(scopedApps.count)")
            sourceInfoLine("近期数量", "\(recentCount)")
            sourceInfoLine("拉黑数量", "0")
            sourceInfoLine("设备", APIClient.shared.deviceID)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            if let source = selectedSource, let reason = source.lockReason {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(YTheme.orange)
                    Text(reason)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(YTheme.orange)
                    Spacer(minLength: 4)
                    if source.requiresCard && !source.unlocked {
                        Button("解锁") { redeemSource = source }
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(YTheme.gradient)
                            .clipShape(Capsule())
                            .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 17)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(YTheme.glass)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.055), radius: 18, x: 0, y: 8)
    }

    private func sourceInfoLine(_ title: String, _ value: String) -> some View {
        Text("\(title)：\(value)")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(YTheme.text.opacity(0.78))
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.76)
    }

    private func announcementCard(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "megaphone.fill")
                .foregroundColor(YTheme.purple)
                .padding(8)
                .background(YTheme.purple.opacity(0.1))
                .clipShape(Circle())
            Text(text)
                .font(.footnote)
                .foregroundColor(YTheme.text)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(YTheme.glass)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.65), lineWidth: 0.8)
        )
    }

    private var globalLockCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 26))
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 3) {
                Text("服务端已开启时间锁")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Text(model.globalLock?.reason ?? "当前 App 受服务端时间限制，请稍后再试")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.82))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(LinearGradient(colors: [YTheme.violet, YTheme.pink], startPoint: .leading, endPoint: .trailing))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    // MARK: - 应用列表

    private var appList: some View {
        LazyVStack(spacing: 11) {
            ForEach(filtered) { item in
                StoreAppRow(item: item)
            }
        }
    }

    private func dateText(_ date: Date?) -> String {
        guard let date else { return "—" }
        return Self.timestampFormatter.string(from: date)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

// MARK: - 应用卡片

struct StoreAppRow: View {
    let item: StoreItem

    private var badge: String {
        item.app.type?.value == "1" ? "插件" : "应用"
    }

    private var badgeColor: Color {
        item.app.type?.value == "1" ? YTheme.violet : YTheme.blue
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            YRemoteIcon(url: item.app.iconLink, fallback: item.app.displayName, size: 60)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(item.app.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(YTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    YSoftPill(title: badge, color: badgeColor)
                }

                HStack(spacing: 5) {
                    Text(item.app.version ?? "—")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(YTheme.red)
                    Text(sizeText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(YTheme.orange)
                    Text(item.app.versionDate.map { "更新于 \(Self.dateTimeFormatter.string(from: $0.date))" } ?? "")
                        .font(.system(size: 9))
                        .foregroundColor(YTheme.muted)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)

                Text(item.app.summary.isEmpty ? item.app.bundleID : item.app.summary)
                    .font(.system(size: 11.5))
                    .foregroundColor(YTheme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            NavigationLink(destination: StoreDetailView(item: item)) {
                Text("查看")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(YTheme.purple)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.42))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(YTheme.purple.opacity(0.55), lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(YTheme.glass)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(Color.white.opacity(0.68), lineWidth: 0.9)
        )
        .shadow(color: Color.black.opacity(0.045), radius: 12, x: 0, y: 5)
    }

    private var sizeText: String {
        guard let size = item.app.size, size > 0 else { return "[0.00M]" }
        return String(format: "[%.2fM]", Double(size) / 1_048_576.0)
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}

// MARK: - 软件源选择

struct SourcePickerView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var selectedSourceID: String?
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            List {
                if model.sources.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("还没有软件源")
                            .font(.headline)
                            .foregroundColor(YTheme.text)
                        Text("管理员还没有在服务端配置默认软件源。")
                            .font(.footnote)
                            .foregroundColor(YTheme.muted)
                        Button("重新加载") {
                            model.refreshConfig()
                            model.refreshStore()
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(YTheme.purple)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                } else {
                    Section(header: Text("服务端下发")) {
                        ForEach(model.sources) { source in
                            Button {
                                selectedSourceID = source.id
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    YRemoteIcon(url: source.iconLink, fallback: source.name, size: 38)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(source.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(YTheme.text)
                                        Text(source.lockReason ?? "已启用")
                                            .font(.caption2)
                                            .foregroundColor(source.lockReason == nil ? YTheme.green : YTheme.orange)
                                    }
                                    Spacer()
                                    if selectedSourceID == source.id || (selectedSourceID == nil && model.sources.first?.id == source.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(YTheme.purple)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    Section {
                        Button {
                            model.refreshConfig()
                            model.refreshStore()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("刷新软件源")
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(YTheme.purple)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("选择软件源")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(YTheme.purple)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - 应用详情

struct StoreDetailView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var downloads = DownloadManager.shared
    let item: StoreItem
    @State private var installError: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                VStack(spacing: 12) {
                    YRemoteIcon(url: item.app.iconLink, fallback: item.app.displayName, size: 96)
                    Text(item.app.displayName).font(.system(size: 23, weight: .bold)).foregroundColor(YTheme.text)
                    Text(item.app.developer ?? item.source.name).font(.caption).foregroundColor(YTheme.muted)
                    HStack(spacing: 8) {
                        YSoftPill(title: item.app.version.map { "v\($0)" } ?? "版本未知", color: YTheme.purple)
                        if let size = item.app.size { YSoftPill(title: ByteCountFormatter.string(fromByteCount: size, countStyle: .file), color: YTheme.blue) }
                        YSoftPill(title: item.source.name, color: YTheme.violet)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(YTheme.softGradient)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                if model.isGloballyLocked {
                    Text("当前服务端已开启时间锁，下载和签名暂不可用。")
                        .font(.footnote).foregroundColor(YTheme.orange).yCard(12)
                }

                VStack(alignment: .leading, spacing: 8) {
                    YSectionTitle(title: "应用介绍")
                    Text(item.app.summary.isEmpty ? "这个应用还没有填写介绍。" : item.app.summary)
                        .font(.subheadline).foregroundColor(YTheme.text.opacity(0.82)).lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .yCard(14)
                }

                VStack(alignment: .leading, spacing: 8) {
                    YSectionTitle(title: "版本信息")
                    infoRow("Bundle ID", item.app.bundleID)
                    infoRow("版本", item.app.version ?? "—")
                    infoRow("更新时间", item.app.versionDate.map { StoreAppRow.dateFormatter.string(from: $0.date) } ?? "—")
                    infoRow("来源", item.source.name)
                }
                .yCard(14)

                Button {
                    if model.isGloballyLocked { installError = "服务端时间锁已开启"; return }
                    downloads.start(item)
                    model.message = "已加入下载队列"
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(!model.allowInstall ? "安装已关闭" : (model.isGloballyLocked ? "暂不可下载" : "下载并准备签名"))
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(YTheme.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
                .opacity((model.isGloballyLocked || !model.allowInstall) ? 0.6 : 1)
            }
            .padding(16)
            .padding(.bottom, 20)
        }
        .background(YTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .alert("提示", isPresented: Binding(
            get: { installError != nil },
            set: { if !$0 { installError = nil } }
        )) {
            Button("好", role: .cancel) { installError = nil }
        } message: {
            Text(installError ?? "")
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).font(.caption).foregroundColor(YTheme.muted).frame(width: 78, alignment: .leading)
            Text(value).font(.caption).foregroundColor(YTheme.text).textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}
