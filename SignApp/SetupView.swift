import SwiftUI

struct SetupView: View {
    var onSave: (URL) -> Void

    @State private var input: String
    @State private var errorText: String?
    @FocusState private var focused: Bool

    init(onSave: @escaping (URL) -> Void) {
        self.onSave = onSave
        _input = State(initialValue: ServerConfig.rawValue)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Theme.accentSoft)
                            .frame(width: 88, height: 88)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundColor(Theme.accent)
                    }

                    Text("连接你的签名站")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundColor(Theme.text)

                    Text("输入站点域名，App 会直接加载你的签名页，客户在手机上即可上传、签名、安装。")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 30)
                }
                .padding(.bottom, 30)

                VStack(alignment: .leading, spacing: 12) {
                    Text("站点地址")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textSecondary)

                    TextField("https://sign.example.com", text: $input)
                        .textFieldStyle(.plain)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.go)
                        .focused($focused)
                        .onSubmit(save)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }

                    Button(action: save) {
                        Text("保存并进入")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 26)

                Spacer()

                Text("站点必须是 HTTPS，HTTP 站点在 iOS 上无法上传文件")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.bottom, 26)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        }
    }

    private func save() {
        guard let url = ServerConfig.save(input) else {
            errorText = "地址格式不正确，例如：https://sign.example.com"
            return
        }
        errorText = nil
        focused = false
        onSave(url)
    }
}
