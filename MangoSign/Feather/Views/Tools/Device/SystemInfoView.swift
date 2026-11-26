//
//  SystemInfoView.swift
//  艺祥签
//
//  系统信息：设备、系统、存储与 App 信息
//

import SwiftUI
import UIKit
import Darwin
import NimbleViews

struct SystemInfoView: View {
	private var _modelIdentifier: String {
		var systemInfo = utsname()
		uname(&systemInfo)
		let mirror = Mirror(reflecting: systemInfo.machine)
		return mirror.children.reduce("") { identifier, element in
			guard let value = element.value as? Int8, value != 0 else { return identifier }
			return identifier + String(UnicodeScalar(UInt8(value)))
		}
	}

	private var _screenSize: String {
		let bounds = UIScreen.main.bounds.size
		let scale = UIScreen.main.scale
		return "\(Int(bounds.width * scale)) × \(Int(bounds.height * scale)) @\(Int(scale))x"
	}

	private var _storage: (total: String, free: String) {
		let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
		let total = (attributes?[.systemSize] as? NSNumber)?.int64Value ?? 0
		let free = (attributes?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		return (
			formatter.string(fromByteCount: total),
			formatter.string(fromByteCount: free)
		)
	}

	private var _memory: String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .memory
		return formatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory))
	}

	var body: some View {
		NBNavigationView("系统信息") {
			NBListAdaptable {
				NBSection("设备") {
					_infoRow("设备名称", UIDevice.current.name)
					_infoRow("机型标识", _modelIdentifier)
					_infoRow("设备型号", UIDevice.current.model)
					_infoRow("系统版本", "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
					if let vendor = UIDevice.current.identifierForVendor?.uuidString {
						_infoRow("设备标识", vendor)
					}
				}

				NBSection("屏幕与存储") {
					_infoRow("屏幕分辨率", _screenSize)
					_infoRow("物理内存", _memory)
					_infoRow("总容量", _storage.total)
					_infoRow("可用容量", _storage.free)
				}

				NBSection("应用") {
					_infoRow("应用名称", Bundle.main.name)
					_infoRow("Bundle ID", Bundle.main.bundleIdentifier ?? "—")
					_infoRow("版本", _appVersion)
					_infoRow("语言 / 地区", "\(Locale.current.identifier)")
					_infoRow("时区", TimeZone.current.identifier)
				} footer: {
					Text("这些信息只在本机读取，不会上传到服务器。")
				}
			}
		}
	}

	private var _appVersion: String {
		let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
		let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
		return "\(version) (\(build))"
	}

	private func _infoRow(_ title: String, _ value: String) -> some View {
		HStack(alignment: .top, spacing: 12) {
			Text(title)
				.font(.subheadline)
				.foregroundStyle(.secondary)
			Spacer(minLength: 12)
			Text(value)
				.font(.subheadline.weight(.medium))
				.multilineTextAlignment(.trailing)
				.textSelection(.enabled)
		}
		.padding(.vertical, 2)
	}
}
