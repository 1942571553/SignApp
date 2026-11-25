import SwiftUI
import UIKit
import WebKit

/// 持有一个 WKWebView 的弱引用，给 SwiftUI 顶部工具条提供前进/后退/刷新等能力
final class WebController: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var pageTitle = ""
    @Published var currentURL: URL?

    weak var webView: WKWebView?

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
    func stop() { webView?.stopLoading() }

    func load(_ url: URL) {
        webView?.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30))
    }

    func clearCache() {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.removeData(ofTypes: types, modifiedSince: Date(timeIntervalSince1970: 0)) { [weak self] in
            DispatchQueue.main.async { self?.webView?.reload() }
        }
    }

    func sync(_ webView: WKWebView) {
        let back = webView.canGoBack
        let forward = webView.canGoForward
        let url = webView.url
        let title = webView.title ?? ""

        // 只在值变化时写入，避免 updateUIView -> @Published -> 重新渲染的死循环
        if canGoBack != back { canGoBack = back }
        if canGoForward != forward { canGoForward = forward }
        if currentURL != url { currentURL = url }
        if !title.isEmpty && pageTitle != title { pageTitle = title }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var controller: WebController

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        controller.webView = webView
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        controller.webView = webView
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.controller.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.controller.isLoading = false
            parent.controller.sync(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.controller.isLoading = false
            parent.controller.sync(webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.controller.isLoading = false
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let scheme = url.scheme?.lowercased() ?? ""

            // 交给系统处理：itms-services（OTA 安装）、mailto、tel、sms
            if ["itms-services", "mailto", "tel", "sms"].contains(scheme) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
                return
            }

            // target=_blank 在 WKWebView 中没有新窗口，改为当前页打开
            if navigationAction.targetFrame == nil {
                DispatchQueue.main.async { webView.load(navigationAction.request) }
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        // MARK: - JS 弹窗

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            guard let host = Coordinator.topViewController() else {
                completionHandler()
                return
            }
            let alert = UIAlertController(title: webView.title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
            host.present(alert, animated: true)
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            guard let host = Coordinator.topViewController() else {
                completionHandler(false)
                return
            }
            let alert = UIAlertController(title: webView.title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler(true) })
            host.present(alert, animated: true)
        }

        static func topViewController() -> UIViewController? {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            var root = scenes.first(where: { $0.activationState == .foregroundActive })?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            if root == nil {
                root = scenes.first?.windows.first?.rootViewController
            }
            while let presented = root?.presentedViewController {
                root = presented
            }
            return root
        }
    }
}
