import Foundation
import Darwin

struct InstallOutcome {
    let ok: Bool
    let message: String
}

enum Installer {
    private static let rootlessPrefix = "/var/jb"
    private static let tools = [
        "/usr/bin/ipainstaller",
        "/usr/bin/appinst",
        "/usr/bin/installipa",
        "/var/jb/usr/bin/ipainstaller",
        "/var/jb/usr/bin/appinst",
        "/var/jb/usr/bin/installipa",
        "/var/jb/usr/local/bin/ipainstaller"
    ]

    static func detectTools() -> [String] {
        tools.filter { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func install(_ ipa: URL) -> InstallOutcome {
        guard let tool = detectTools().first else {
            return InstallOutcome(ok: false, message: "没找到 ipainstaller/appinst。请在 Sileo 里装 AppSync Unified 或 ipainstaller 后重试；也可以点“分享”把签名包发给 TrollStore 安装。")
        }
        let code = spawn(tool, [tool, ipa.path])
        if code == 0 {
            return InstallOutcome(ok: true, message: "已交给 \(tool) 安装，回桌面看进度。")
        }
        return InstallOutcome(ok: false, message: "\(tool) 返回 \(code)，可能没有越狱权限。可改用 TrollStore 安装。")
    }

    private static func spawn(_ path: String, _ args: [String]) -> Int32 {
        var pid: pid_t = 0
        var argv: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
        argv.append(nil)
        let result = posix_spawn(&pid, path, nil, nil, &argv, environ)
        if result != 0 { return result }
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        return (status >> 8) & 0xFF
    }
}
