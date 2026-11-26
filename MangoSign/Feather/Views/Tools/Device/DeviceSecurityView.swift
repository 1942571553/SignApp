//
//  DeviceSecurityView.swift
//  艺祥签
//
//  设备安全：检查常见的越狱环境痕迹
//

import SwiftUI
import UIKit
import NimbleViews

struct DeviceSecurityView: View {
	private struct Check: Identifiable {
		let id = UUID()
		let title: String
		let detail: String
		let passed: Bool
	}

	private var _checks: [Check] {
		var checks: [Check] = []

		let paths: [(String, String)] = [
			("/Applications/Cydia.app", "Cydia 应用"),
			("/Library/MobileSubstrate/MobileSubstrate.dylib", "MobileSubstrate"),
			("/bin/bash", "Bash Shell"),
			("/usr/sbin/sshd", "SSH 服务"),
			("/etc/apt", "APT 包管理器"),
			("/private/var/lib/apt", "APT 数据目录")
		]

		for (path, name) in paths {
			let exists = FileManager.default.fileExists(atPath: path)
			checks.append(
				Check(
					title: name,
					detail: exists ? "检测到文件：\(path)" : "未发现 \(path)",
					passed: !exists
				)
			)
		}

		let cydiaURL = URL(string: "cydia://")!
		let canOpenCydia = UIApplication.shared.canOpenURL(cydiaURL)
		checks.append(
			Check(
				title: "Cydia URL Scheme",
				detail: canOpenCydia ? "系统可以打开 cydia://" : "未注册 cydia:// 协议",
				passed: !canOpenCydia
			)
		)

		return checks
	}

	private var _isSafe: Bool {
		_checks.allSatisfy { $0.passed }
	}

	var body: some View {
		NBNavigationView("设备安全") {
			NBListAdaptable {
				Section {
					HStack(spacing: 14) {
						ZStack {
							Circle()
								.fill((_isSafe ? Color(hex: "#21A366") : Color(hex: "#E08A1E")).opacity(0.12))
								.frame(width: 58, height: 58)
							Image(systemName: _isSafe ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
								.font(.system(size: 26, weight: .semibold))
								.foregroundStyle(_isSafe ? Color(hex: "#21A366") : Color(hex: "#E08A1E"))
						}

						VStack(alignment: .leading, spacing: 4) {
							Text(_isSafe ? "未检测到越狱迹象" : "检测到可疑环境")
								.font(.headline)
							Text(_isSafe ? "当前设备环境适合运行签名工具。" : "部分签名和安装功能可能受影响，请谨慎操作。")
								.font(.caption)
								.foregroundStyle(.secondary)
								.fixedSize(horizontal: false, vertical: true)
						}

						Spacer(minLength: 0)
					}
					.padding(.vertical, 6)
				}

				NBSection("检测项目", secondary: "\(_checks.filter { $0.passed }.count)/\(_checks.count)") {
					ForEach(_checks) { check in
						HStack(spacing: 12) {
							Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
								.font(.system(size: 18, weight: .semibold))
								.foregroundStyle(check.passed ? Color(hex: "#21A366") : Color(hex: "#D9534F"))

							VStack(alignment: .leading, spacing: 3) {
								Text(check.title)
									.font(.subheadline.weight(.medium))
								Text(check.detail)
									.font(.caption2)
									.foregroundStyle(.secondary)
									.lineLimit(2)
							}

							Spacer(minLength: 0)
						}
						.padding(.vertical, 3)
					}
				} footer: {
					Text("检测仅基于常见文件与 URL Scheme，不能覆盖所有越狱形态；结果仅供参考。")
				}
			}
		}
	}
}
