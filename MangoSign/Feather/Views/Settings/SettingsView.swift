//
//  SettingsView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews
import UIKit
import Darwin
import IDeviceSwift

// MARK: - View
struct SettingsView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	@State private var _currentIcon: String? = UIApplication.shared.alternateIconName
	@StateObject private var _brand = BrandStore.shared
	@State private var _isSyncing = false
	@State private var _isSourcesPresenting = false

	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>

	@FetchRequest(
		entity: Signed.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
		animation: .snappy
	) private var _signedApps: FetchedResults<Signed>

	@FetchRequest(
		entity: Imported.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Imported.date, ascending: false)],
		animation: .snappy
	) private var _importedApps: FetchedResults<Imported>

	private var selectedCertificate: CertificatePair? {
		guard
			_storedSelectedCert >= 0,
			_storedSelectedCert < _certificates.count
		else {
			return nil
		}
		return _certificates[_storedSelectedCert]
	}

	private let _sourceUrl = "https://github.com/1942571553/SignApp"

	private var _accent: Color { _brand.themeColor }

	// MARK: Body
	var body: some View {
		NBNavigationView("我的") {
			ScrollView {
				VStack(spacing: 16) {
					_profileCard()
					_serviceCard()
					_certificateGroup()
					_signingGroup()
					_appGroup()
					_appearanceGroup()
					_serverCard()
					_aboutCard()
				}
				.padding(.horizontal, 16)
				.padding(.top, 8)
				.padding(.bottom, 32)
			}
			.background(Color(uiColor: .systemGroupedBackground))
			.scrollIndicators(.hidden)
			.sheet(isPresented: $_isSourcesPresenting) {
				SourcesView()
			}
		}
	}
}

// MARK: - Cards
extension SettingsView {
	@ViewBuilder
	private func _profileCard() -> some View {
		VStack(alignment: .leading, spacing: 18) {
			HStack(alignment: .center, spacing: 14) {
				FRAppIconView(size: 62)
					.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

				VStack(alignment: .leading, spacing: 5) {
					Text(_brand.displayName)
						.font(.title3.weight(.bold))
						.foregroundStyle(.white)

					HStack(spacing: 7) {
						Text("本地签名模式")
							.font(.caption2.weight(.semibold))
							.foregroundStyle(.white)
							.padding(.horizontal, 8)
							.padding(.vertical, 4)
							.background(.white.opacity(0.18), in: Capsule())

						Text(_appVersion)
							.font(.caption2)
							.foregroundStyle(.white.opacity(0.78))
					}
				}

				Spacer(minLength: 0)

				NavigationLink {
					ServiceCenterView()
				} label: {
					HStack(spacing: 5) {
						Image(systemName: "person.crop.circle")
							.font(.caption2.weight(.semibold))
						Text("账号")
							.font(.caption2.weight(.semibold))
					}
					.foregroundStyle(.white)
					.padding(.horizontal, 10)
					.padding(.vertical, 6)
					.background(.white.opacity(0.18), in: Capsule())
				}
				.buttonStyle(.plain)
			}

			HStack(spacing: 0) {
				_profileStat(value: "\(_signedApps.count)", title: "已签名")
				Divider().overlay(.white.opacity(0.22))
				_profileStat(value: "\(_importedApps.count)", title: "应用")
				Divider().overlay(.white.opacity(0.22))
				_profileStat(value: "\(_certificates.count)", title: "证书")
			}
			.frame(height: 44)
		}
		.padding(20)
		.background(
			ZStack(alignment: .topTrailing) {
				LinearGradient(
					colors: [
						_accent,
						_accent.opacity(0.82),
						Color(hex: "#123B2A")
					],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)

				Circle()
					.fill(.white.opacity(0.10))
					.frame(width: 180, height: 180)
					.offset(x: 62, y: -86)
			}
		)
		.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
		.shadow(color: _accent.opacity(0.22), radius: 18, x: 0, y: 10)
	}

	private func _profileStat(value: String, title: String) -> some View {
		VStack(spacing: 4) {
			Text(value)
				.font(.headline.weight(.bold))
				.foregroundStyle(.white)
			Text(title)
				.font(.caption2)
				.foregroundStyle(.white.opacity(0.72))
		}
		.frame(maxWidth: .infinity)
	}

	@ViewBuilder
	private func _serviceCard() -> some View {
		VStack(spacing: 0) {
			HStack(spacing: 12) {
				VStack(alignment: .leading, spacing: 4) {
					HStack(spacing: 6) {
						Circle()
							.fill(Color(hex: "#21A366"))
							.frame(width: 7, height: 7)
						Text("本机签名服务")
							.font(.subheadline.weight(.semibold))
					}
					Text("证书与安装包只保存在本机")
						.font(.caption2)
						.foregroundStyle(.secondary)
				}

				Spacer(minLength: 0)

				Text("不限次数")
					.font(.caption.weight(.semibold))
					.foregroundStyle(_accent)
					.padding(.horizontal, 10)
					.padding(.vertical, 6)
					.background(_accent.opacity(0.12), in: Capsule())
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 14)

			Divider().padding(.leading, 16)

			NavigationLink {
				ServiceCenterView()
			} label: {
				HStack(spacing: 12) {
					Image(systemName: "cart.fill")
						.font(.system(size: 16, weight: .semibold))
						.foregroundStyle(Color(hex: "#E08A1E"))
						.frame(width: 34, height: 34)
						.background(Color(hex: "#E08A1E").opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

					VStack(alignment: .leading, spacing: 2) {
						Text("账号与商城")
							.font(.subheadline.weight(.semibold))
							.foregroundStyle(.primary)
						Text("余额、购买证书、授权记录")
							.font(.caption2)
							.foregroundStyle(.secondary)
					}

					Spacer(minLength: 0)

					Text("待接入")
						.font(.caption2.weight(.semibold))
						.foregroundStyle(.secondary)
						.padding(.horizontal, 8)
						.padding(.vertical, 4)
						.background(Color(uiColor: .quaternarySystemFill), in: Capsule())

					Image(systemName: "chevron.right")
						.font(.caption2.weight(.semibold))
						.foregroundStyle(.tertiary)
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 12)
			}
			.buttonStyle(.plain)
		}
		.background(
			Color(uiColor: .secondarySystemGroupedBackground),
			in: RoundedRectangle(cornerRadius: 22, style: .continuous)
		)
	}
}

// MARK: - Menu Groups
extension SettingsView {
	@ViewBuilder
	private func _certificateGroup() -> some View {
		_menuCard(title: "证书与签名") {
			if let cert = selectedCertificate {
				CertificatesCellView(cert: cert)
					.padding(.horizontal, 12)
				Divider().padding(.leading, 16)
			}

			_linkRow(title: "证书管理", subtitle: _certificates.isEmpty ? "还没有可用证书" : "\(_certificates.count) 个证书", icon: "checkmark.seal.fill", color: Color(hex: "#21A366")) {
				CertificatesView()
			}
			Divider().padding(.leading, 62)
			_linkRow(title: "签名设置", subtitle: "显示名、Bundle ID、版本", icon: "signature", color: _accent) {
				ConfigurationView()
			}
			Divider().padding(.leading, 62)
			_linkRow(title: "安装设置", subtitle: "安装方式与服务端", icon: "arrow.down.app.fill", color: Color(hex: "#8E5CF7")) {
				InstallationView()
			}
		}
	}

	@ViewBuilder
	private func _signingGroup() -> some View {
		_menuCard(title: "应用与数据") {
			Button {
				_isSourcesPresenting = true
			} label: {
				_rowLabel(title: "软件源", subtitle: "添加与管理应用源", icon: "globe.desk.fill", color: Color(hex: "#3E7BFA"))
			}
			.buttonStyle(.plain)
			Divider().padding(.leading, 62)
			_linkRow(title: "压缩归档", subtitle: "导出格式与压缩级别", icon: "archivebox.fill", color: Color(hex: "#C77B30")) {
				ArchiveView()
			}
			Divider().padding(.leading, 62)
			_buttonRow(title: "文件目录", subtitle: "在文件中查看 IPA", icon: "folder.fill", color: Color(hex: "#0F766E")) {
				_openDocuments()
			}
			Divider().padding(.leading, 62)
			_linkRow(title: "清理缓存", subtitle: "重置应用数据", icon: "trash.fill", color: Color(hex: "#6B7280")) {
				ResetView()
			}
		}
	}

	@ViewBuilder
	private func _appGroup() -> some View {
		_menuCard(title: "设备与系统") {
			_linkRow(title: "系统信息", subtitle: "设备、存储、系统版本", icon: "iphone.gen3", color: Color(hex: "#2F6FED")) {
				SystemInfoView()
			}
			Divider().padding(.leading, 62)
			_linkRow(title: "设备安全", subtitle: "越狱环境检测", icon: "lock.shield.fill", color: Color(hex: "#21A366")) {
				DeviceSecurityView()
			}
			Divider().padding(.leading, 62)
			_linkRow(title: "网络检测", subtitle: "检查签名服务连接", icon: "wifi", color: Color(hex: "#8E5CF7")) {
				NetworkCheckView()
			}
		}
	}

	@ViewBuilder
	private func _appearanceGroup() -> some View {
		_menuCard(title: "外观与关于") {
			_linkRow(title: "外观设置", subtitle: "主题色与显示方式", icon: "paintbrush.fill", color: Color(hex: "#D65A8C")) {
				AppearanceView()
			}
			Divider().padding(.leading, 62)
			_linkRow(title: "App 图标", subtitle: "切换桌面图标", icon: "app.badge", color: Color(hex: "#8E5CF7")) {
				AppIconView(currentIcon: $_currentIcon)
			}
			Divider().padding(.leading, 62)
			_linkRow(title: "关于艺祥签", subtitle: "版本与开源声明", icon: "info.circle.fill", color: _accent) {
				AboutView()
			}
			Divider().padding(.leading, 62)
			if let url = _brand.supportURL {
				_buttonRow(title: "联系客服", subtitle: "使用问题与售后", icon: "bubble.left.and.bubble.right.fill", color: Color(hex: "#3E7BFA")) {
					UIApplication.shared.open(url)
				}
			}
		}
	}

	@ViewBuilder
	private func _serverCard() -> some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 8) {
				Image(systemName: "lock.fill")
					.font(.caption)
					.foregroundStyle(.secondary)
				Text("服务器")
					.font(.subheadline.weight(.semibold))
				Spacer(minLength: 0)
				Button {
					_isSyncing = true
					Task {
						await _brand.refresh()
						_isSyncing = false
					}
				} label: {
					if _isSyncing {
						ProgressView().controlSize(.mini)
					} else {
						Image(systemName: "arrow.clockwise")
							.font(.caption.weight(.semibold))
					}
				}
				.disabled(_isSyncing)
			}

			Text(verbatim: _brand.configURL)
				.font(.caption2)
				.foregroundStyle(.secondary)
				.lineLimit(2)
				.textSelection(.enabled)

			HStack(spacing: 6) {
				Circle()
					.fill(_brand.lastError == nil && _brand.lastSync != nil ? Color(hex: "#21A366") : Color(hex: "#E08A1E"))
					.frame(width: 6, height: 6)
				Text(_brand.lastError == nil && _brand.lastSync != nil ? "远程配置已同步" : "等待同步远程配置")
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(16)
		.background(
			Color(uiColor: .secondarySystemGroupedBackground),
			in: RoundedRectangle(cornerRadius: 20, style: .continuous)
		)
	}

	@ViewBuilder
	private func _aboutCard() -> some View {
		VStack(spacing: 8) {
			Text(verbatim: "\(Bundle.main.name) · \(_appVersion)")
				.font(.caption2)
				.foregroundStyle(.secondary)
			Text("基于 Feather（GPL-3.0）二次开发，界面与功能为艺祥签定制。")
				.font(.caption2)
				.foregroundStyle(.tertiary)
				.multilineTextAlignment(.center)
		}
		.frame(maxWidth: .infinity)
		.padding(.top, 4)
	}
}

// MARK: - Components
extension SettingsView {
	@ViewBuilder
	private func _menuCard<Content: View>(
		title: String,
		@ViewBuilder content: () -> Content
	) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			Text(title)
				.font(.footnote.weight(.bold))
				.foregroundStyle(.secondary)
				.padding(.horizontal, 4)

			VStack(spacing: 0) {
				content()
			}
			.background(
				Color(uiColor: .secondarySystemGroupedBackground),
				in: RoundedRectangle(cornerRadius: 20, style: .continuous)
			)
		}
	}

	@ViewBuilder
	private func _linkRow<Destination: View>(
		title: String,
		subtitle: String,
		icon: String,
		color: Color,
		@ViewBuilder destination: () -> Destination
	) -> some View {
		NavigationLink {
			destination()
		} label: {
			_rowLabel(title: title, subtitle: subtitle, icon: icon, color: color)
		}
		.buttonStyle(.plain)
	}

	@ViewBuilder
	private func _buttonRow(
		title: String,
		subtitle: String,
		icon: String,
		color: Color,
		action: @escaping () -> Void
	) -> some View {
		Button(action: action) {
			_rowLabel(title: title, subtitle: subtitle, icon: icon, color: color)
		}
		.buttonStyle(.plain)
	}

	private func _rowLabel(title: String, subtitle: String, icon: String, color: Color) -> some View {
		HStack(spacing: 12) {
			Image(systemName: icon)
				.font(.system(size: 16, weight: .semibold))
				.foregroundStyle(color)
				.frame(width: 34, height: 34)
				.background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(.primary)
				Text(subtitle)
					.font(.caption2)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}

			Spacer(minLength: 0)

			Image(systemName: "chevron.right")
				.font(.caption2.weight(.semibold))
				.foregroundStyle(.tertiary)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 12)
		.contentShape(Rectangle())
	}
}

// MARK: - Helpers
extension SettingsView {
	private var _appVersion: String {
		let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
		let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
		return "v\(version) (\(build))"
	}

	private func _openDocuments() {
		guard let url = URL.documentsDirectory.toSharedDocumentsURL() else { return }
		UIApplication.shared.open(url)
	}
}
