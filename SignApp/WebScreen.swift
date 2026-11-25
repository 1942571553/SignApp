import SwiftUI
import UIKit

struct WebScreen: View {
    let url: URL
    /// 站点地址被修改后通知上层重新加载根视图
    let onServerChange: () -> Void

    @StateObject private var controller = WebController()
    @State private var showSetup = false

    var body: some View {
        WebView(url: url, controller: controller)
            .id(url)
            .safeAreaInset(edge: .top, spacing: 0) { topBar }
            .sheet(isPresented: $showSetup) {
                SetupView { saved in
                    showSetup = false
                    if saved.absoluteString != url.absoluteString {
                        onServerChange()
                    }
                }
            }
    }

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    controller.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .disabled(!controller.canGoBack)
                .opacity(controller.canGoBack ? 1 : 0.28)

                Button {
                    controller.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .disabled(!controller.canGoForward)
                .opacity(controller.canGoForward ? 1 : 0.28)

                Text(controller.pageTitle.isEmpty ? "签名助手" : controller.pageTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)

                Button {
                    controller.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 30, height: 30)
                }

                Menu {
                    Button {
                        let target = controller.currentURL ?? url
                        UIApplication.shared.open(target, options: [:], completionHandler: nil)
                    } label: {
                        Label("在 Safari 中打开", systemImage: "safari")
                    }

                    Button {
                        controller.reload()
                    } label: {
                        Label("重新加载", systemImage: "arrow.clockwise")
                    }

                    Button {
                        controller.clearCache()
                    } label: {
                        Label("清除缓存", systemImage: "trash")
                    }

                    Divider()

                    Button {
                        showSetup = true
                    } label: {
                        Label("更换服务器地址", systemImage: "server.rack")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 30, height: 30)
                }
            }
            .tint(Theme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            if controller.isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .frame(height: 2)
                    .tint(Theme.accent)
            }
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}
