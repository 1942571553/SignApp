import SwiftUI

struct RootView: View {
    @State private var serverURL: URL? = ServerConfig.current

    var body: some View {
        Group {
            if let serverURL {
                WebScreen(url: serverURL) {
                    self.serverURL = ServerConfig.current
                }
            } else {
                SetupView { url in
                    self.serverURL = url
                }
            }
        }
        .accentColor(Theme.accent)
    }
}
