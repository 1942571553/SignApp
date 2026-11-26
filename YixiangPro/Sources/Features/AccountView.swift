import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.presentationMode) private var presentation
    @State private var mode = 0
    @State private var username = ""
    @State private var password = ""
    @State private var error: String?
    @State private var showLogin = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    if let user = model.user {
                        profile(user)
                        deviceCard
                        Button {
                            model.logout()
                            presentation.wrappedValue.dismiss()
                        } label: {
                            Text("退出登录")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(YTheme.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(YTheme.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    } else {
                        loginPanel
                    }
                    Text("账号数据由服务端统一管理，管理员可在后台查看注册用户、设备与授权状态。")
                        .font(.caption2)
                        .foregroundColor(YTheme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(16)
            }
            .background(YTheme.background.ignoresSafeArea())
            .navigationTitle("账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { presentation.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func profile(_ user: UserInfo) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.white.opacity(0.18)).frame(width: 82, height: 82)
                Image(systemName: "person.fill").font(.system(size: 34)).foregroundColor(.white)
            }
            Text(user.username).font(.system(size: 23, weight: .bold)).foregroundColor(.white)
            HStack(spacing: 8) {
                Text(user.role == "admin" ? "管理员" : "普通用户")
                Text("ID \(user.id)")
                if let days = model.remainingDays { Text(days > 0 ? "剩余 \(days) 天" : "已到期") }
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(YTheme.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            YSectionTitle(title: "当前设备")
            info("设备标识", APIClient.shared.deviceID)
            info("系统版本", UIDevice.current.systemName + " " + UIDevice.current.systemVersion)
            info("型号", UIDevice.current.model)
        }
        .yCard(14)
    }

    private var loginPanel: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                segment("登录", 0)
                segment("注册", 1)
            }
            .padding(3)
            .background(YTheme.soft)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(spacing: 10) {
                field(icon: "person.fill", placeholder: "用户名", text: $username)
                secureField(icon: "lock.fill", placeholder: "密码", text: $password)
            }

            if let error {
                Text(error).font(.caption).foregroundColor(YTheme.red).multilineTextAlignment(.center)
            }

            Button {
                submit()
            } label: {
                HStack {
                    if model.authBusy { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                    Text(mode == 0 ? "登录账号" : "注册账号")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(YTheme.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(model.authBusy || username.isEmpty || password.isEmpty)

            Text(mode == 0 ? "还没有账号？切换到注册，立即创建。" : "注册后可在后台统一管理设备与授权。")
                .font(.caption2).foregroundColor(YTheme.muted)
        }
        .yCard(18)
    }

    private func segment(_ title: String, _ index: Int) -> some View {
        Button { mode = index } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(mode == index ? .white : YTheme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(mode == index ? AnyView(YTheme.gradient) : AnyView(Color.clear))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }

    private func field(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(YTheme.purple).frame(width: 20)
            TextField(placeholder, text: text)
                .font(.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
        }
        .padding(13)
        .background(YTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func secureField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(YTheme.purple).frame(width: 20)
            SecureField(placeholder, text: text)
                .font(.subheadline)
        }
        .padding(13)
        .background(YTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func submit() {
        error = nil
        let action: (@escaping (Bool, String?) -> Void) -> Void = { completion in
            if mode == 0 {
                model.login(username: username, password: password, completion: completion)
            } else {
                model.register(username: username, password: password, completion: completion)
            }
        }
        action { ok, message in
            if ok {
                presentation.wrappedValue.dismiss()
            } else {
                error = message ?? "操作失败"
            }
        }
    }

    private func info(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).font(.caption).foregroundColor(YTheme.muted).frame(width: 76, alignment: .leading)
            Text(value).font(.caption).foregroundColor(YTheme.text).lineLimit(2)
            Spacer(minLength: 0)
        }
    }
}
