import SwiftUI

struct StoreView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var downloads = DownloadManager.shared
    @State private var query = ""
    @State private var category = "全部"
    @State private var showAccount = false
    @State private var redeemSource: RemoteSource?

    private var categories: [String] {
        var values = ["全部", "应用", "游戏", "工具", "插件"]
        let extra = Set(model.apps.compactMap { $0.app.category?.isEmpty == false ? $0.app.category! : nil })
        values.append(contentsOf: extra.filter { !values.contains($0) }.sorted())
        return values
    }

    private var filtered: [StoreItem] {
        model.apps.filter { item in
            let matchesQuery = query.isEmpty
                || item.app.displayName.localizedCaseInsensitiveContains(query)
                || item.app.summary.localizedCaseInsensitiveContains(query)
                || item.app.bundleID.localizedCaseInsensitiveContains(query)
            guard matchesQuery else { return false }
            guard category != "全部" else { return true }
            let cat = item.app.category ?? ""
            if category == "应用" { return cat.isEmpty || cat.contains("应用") || cat.contains("Utilities") }
            return cat.localizedCaseInsensitiveContains(category)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    if let announcement = model.announcement, !announcement.isEmpty {
                        announcementCard(announcement)
                    }
                    if model.isGloballyLocked {
                        globalLockCard
                    }
                    searchBar
                    categoryBar
                    sourceStrip
                    if filtered.isEmpty {
                        YEmpty(
                            icon: "shippingbox",
                            title: model.isLoading ? "正在同步软件源" : "暂无应用",
                            message: model.isLoading ? "正在从服务端拉取应用数据…" : "服务端还没有可用软件源，或者当前分类没有应用。",
                            action: { model.refreshStore() },
                            actionTitle: "重新加载"
                        )
                    } else {
                        appList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(YTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showAccount) { AccountView() }
        .sheet(item: $redeemSource) { source in
            CardRedeemView(source: source)
                .environmentObject(model)
        }
    }

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(YTheme.gradient)
            Circle().fill(Color.white.opacity(0.15)).frame(width: 150, height: 150).offset(x: 65, y: -55)
            Circle().fill(Color.white.opacity(0.08)).frame(width: 100, height: 100).offset(x: 30, y: 55)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.displayName)
                            .font(.system(size: 27, weight: .heavy))
                            .foregroundColor(.white)
                        Text(model.subtitle)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.78))
                    }
                    Spacer()
                    Button { showAccount = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: model.isLoggedIn ? "person.crop.circle.fill" : "person.crop.circle")
                            Text(model.isLoggedIn ? (model.user?.username ?? "账号") : "登录")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                HStack(spacing: 0) {
                    stat("\(model.apps.count)", "应用")
                    divider
                    stat("\(model.sources.count)", "软件源")
                    divider
                    stat("\(model.signed.count)", "已签名")
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.top, 2)
            }
            .padding(20)
        }
        .frame(height: 158)
        .clipped()
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.24)).frame(width: 0.7, height: 24).padding(.horizontal, 18)
    }

    private func stat(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
            Text(title).font(.system(size: 9.5)).foregroundColor(.white.opacity(0.7))
        }
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
        .yCard(12)
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
            }
            Spacer()
        }
        .padding(14)
        .background(LinearGradient(colors: [YTheme.violet, YTheme.pink], startPoint: .leading, endPoint: .trailing))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(YTheme.muted)
            TextField("搜索应用、Bundle ID", text: $query)
                .font(.subheadline)
                .foregroundColor(YTheme.text)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(YTheme.muted) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(YTheme.border, lineWidth: 0.8))
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { value in
                    Button { category = value } label: {
                        Text(value)
                            .font(.caption.weight(category == value ? .bold : .medium))
                            .foregroundColor(category == value ? .white : YTheme.muted)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(category == value ? AnyView(YTheme.gradient) : AnyView(Color.white))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(category == value ? Color.clear : YTheme.border, lineWidth: 0.7))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var sourceStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            YSectionTitle(title: "软件源", subtitle: "服务端下发", trailing: "\(model.sources.count) 个")
            if model.sources.isEmpty {
                Text("管理员还没有配置默认软件源")
                    .font(.footnote)
                    .foregroundColor(YTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .yCard(12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(model.sources) { source in
                            Button {
                                if let reason = source.lockReason {
                                    if source.requiresCard && !source.unlocked { redeemSource = source }
                                    else { model.message = reason }
                                } else {
                                    redeemSource = nil
                                }
                            } label: {
                                sourceChip(source)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private func sourceChip(_ source: RemoteSource) -> some View {
        HStack(spacing: 9) {
            YRemoteIcon(url: source.iconLink, fallback: source.name, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name).font(.caption.weight(.semibold)).foregroundColor(YTheme.text).lineLimit(1)
                Text(source.lockReason ?? "已启用").font(.system(size: 9)).foregroundColor(source.lockReason == nil ? YTheme.green : YTheme.orange)
            }
            if source.lockReason != nil {
                Image(systemName: "lock.fill").font(.system(size: 9)).foregroundColor(YTheme.orange)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(YTheme.border, lineWidth: 0.7))
    }

    private var appList: some View {
        VStack(spacing: 10) {
            YSectionTitle(title: "全部应用", subtitle: "源驱动商店", trailing: "\(filtered.count) 款")
            LazyVStack(spacing: 10) {
                ForEach(filtered) { item in
                    NavigationLink(destination: StoreDetailView(item: item)) {
                        StoreAppRow(item: item)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

struct StoreAppRow: View {
    let item: StoreItem

    var body: some View {
        HStack(spacing: 12) {
            YRemoteIcon(url: item.app.iconLink, fallback: item.app.displayName, size: 54)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.app.displayName).font(.system(size: 15, weight: .semibold)).foregroundColor(YTheme.text).lineLimit(1)
                    if let type = item.app.type?.value, type == "1" {
                        YSoftPill(title: "插件", color: YTheme.violet)
                    }
                }
                Text(item.app.summary.isEmpty ? item.app.bundleID : item.app.summary)
                    .font(.caption).foregroundColor(YTheme.muted).lineLimit(1)
                HStack(spacing: 7) {
                    Text(item.app.version.map { "v\($0)" } ?? "—")
                    Text(sizeText)
                    Text(item.app.versionDate.map { Self.dateFormatter.string(from: $0.date) } ?? "")
                }
                .font(.system(size: 9.5))
                .foregroundColor(YTheme.muted.opacity(0.9))
            }
            Spacer(minLength: 2)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(YTheme.muted.opacity(0.6))
        }
        .yCard(11)
    }

    private var sizeText: String {
        guard let size = item.app.size else { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
}

struct StoreDetailView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var downloads = DownloadManager.shared
    let item: StoreItem
    @State private var showAccount = false
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
                        Text(model.isGloballyLocked ? "暂不可下载" : "下载并准备签名")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(YTheme.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(model.isGloballyLocked ? 0.6 : 1)
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
        .sheet(isPresented: $showAccount) { AccountView() }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).font(.caption).foregroundColor(YTheme.muted).frame(width: 78, alignment: .leading)
            Text(value).font(.caption).foregroundColor(YTheme.text).textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}
