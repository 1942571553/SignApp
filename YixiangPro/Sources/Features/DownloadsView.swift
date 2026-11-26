import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var downloads = DownloadManager.shared
    @State private var signTarget: ImportedApp?

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    if downloads.items.isEmpty {
                        YEmpty(icon: "arrow.down.circle", title: "暂无下载", message: "在“应用”页选择应用下载，进度会显示在这里。")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(downloads.items) { item in
                                downloadRow(item)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(YTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(item: $signTarget) { app in SigningSheet(app: app).environmentObject(model) }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("下载").font(.system(size: 26, weight: .heavy)).foregroundColor(YTheme.text)
                Text("下载完成后自动导入待签名").font(.caption).foregroundColor(YTheme.muted)
            }
            Spacer()
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 27)).foregroundColor(.white)
                .frame(width: 52, height: 52).background(YTheme.gradient).clipShape(Circle())
        }
    }

    private func downloadRow(_ item: DownloadItem) -> some View {
        VStack(spacing: 9) {
            HStack(spacing: 11) {
                YRemoteIcon(url: item.iconURL, fallback: item.name, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(.subheadline.weight(.semibold)).foregroundColor(YTheme.text).lineLimit(1)
                    Text(item.sourceName).font(.caption2).foregroundColor(YTheme.muted)
                }
                Spacer()
                statusView(item)
            }
            if item.state == .downloading || item.state == .waiting {
                ProgressView(value: item.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: YTheme.purple))
                HStack {
                    Text("\(Int(item.progress * 100))%").font(.system(size: 9)).foregroundColor(YTheme.muted)
                    Spacer()
                }
            } else if item.state == .failed {
                Text(item.error ?? "下载失败").font(.caption2).foregroundColor(YTheme.red)
            } else if item.state == .completed {
                HStack {
                    Text("已导入，去签名").font(.caption2).foregroundColor(YTheme.green)
                    Spacer()
                    if let imported = model.imported.first(where: { $0.ipaPath == item.localPath }) {
                        Button("签名") { signTarget = imported }
                            .font(.caption.weight(.semibold)).foregroundColor(YTheme.purple)
                    }
                }
            }
        }
        .yCard(12)
    }

    @ViewBuilder
    private func statusView(_ item: DownloadItem) -> some View {
        switch item.state {
        case .waiting:
            Text("等待中").font(.caption2).foregroundColor(YTheme.muted)
        case .downloading:
            Text("下载中").font(.caption2).foregroundColor(YTheme.purple)
        case .completed:
            Label("完成", systemImage: "checkmark.circle.fill").font(.caption2).foregroundColor(YTheme.green)
        case .failed:
            Label("失败", systemImage: "exclamationmark.circle.fill").font(.caption2).foregroundColor(YTheme.red)
        }
    }
}
