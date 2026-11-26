//
//  SettingsView.swift
//  艺祥签
//
//  ABox 架构的第五页：设置。证书、签名、软件源、设备工具与关于。
//

import SwiftUI
import NimbleViews
import UIKit
import CoreData

struct SettingsView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	@State private var _currentIcon: String? = UIApplication.shared.alternateIconName
	@StateObject private var _brand = BrandStore.shared
	@State private var _isSourcesPresenting = false

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

	private var _appVersion: String {
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.0"
	}

	var body: some View {
		NBNavigationView("") {
			ScrollView {
				VStack(spacing: 14) {
					_profileCard()
					_accountCard()
					_certificateGroup()
					_appGroup()
					_deviceGroup()
					_appearanceGroup()
					_aboutGroup()
				}
				.padding(.horizontal, 16)
				.padding(.top, 6)
				.padding(.bottom, 34)
			}
			.background(HiboxTheme.background)
			.scrollIndicators(.hidden)
			.toolbar(.hidden, for: .navigationBar)
			.sheet(isPresented: $_isSourcesPresenting) {
				SourcesView()
			}
		}
	}
}

// MARK: - Header
extension SettingsView {
	@ViewBuilder
	private func _profileCard() -> some View {
		VStack(spacing: 16) {
			HStack(alignment: .center, spacing: 14) {
				FRAppIconView(size: 60)
					.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
					.overlay(
						RoundedRectangle(cornerRadius: 16, style: .continuous)
							.stroke(.white.opacity(0.26), lineWidth: 1)
					)

				VStack(alignment: .leading, spacing: 5) {
					Text(_brand.displayName)
						.font(.system(size: 21, weight: .bold))
						.foregroundStyle(.white)

					HStack(spacing: 6) {
						Text("本地签名模式")
							.font(.caption2.weight(.semibold))
							.foregroundStyle(.white)
							.padding(.horizontal, 8)
							.padding(.vertical, 4)
							.background(.white.opacity(0.18), in: Capsule())

						Text("v\(_appVersion)")
							.font(.caption2)
							.foregroundStyle(.white.opacity(0.78))
					}
				}

				Spacer(minLength: 0)

				Image(systemName: "chevron.right")
					.font(.system(size: 12, weight: .bold))
					.foregroundStyle(.white.opacity(0.6))
			}

			HStack(spacing: 0) {
				_profileStat(value: "\(_certificates.count)", title: "证书")
				_profileDivider()
				_profileStat(value: "\(_signedApps.count)", title: "已签名")
				_profileDivider()
				_profileStat(value: "\(_importedApps.count)", title: "待签名")
			}
			.padding(.top, 2)
		}
		.padding(18)
		.background(
			ZStack(alignment: .topTrailing) {
				HiboxTheme.gradient
				Circle()
					.fill(.white.opacity(0.13))
					.frame(width: 180, height: 180)
					.offset(x: 60, y: -90)
				Circle()
					.fill(.white.opacity(0.08))
					.frame(width: 100, height: 100)
					.offset(x: -10, y: 110)
			}
		)
		.clipShape(RoundedRectangle(cornerRadius: HiboxTheme.largeRadius, style: .continuous))
		.shadow(color: HiboxTheme.purple.opacity(0.18), radius: 16, x: 0, y: 8)
	}

	private func _profileStat(value: String, title: String) -> some View {
		VStack(spacing: 4) {
			Text(value)
				.font(.system(size: 19, weight: .bold))
				.foregroundStyle(.white)
			Text(title)
				.font(.caption2)
				.foregroundStyle(.white.opacity(0.72))
		}
		.frame(maxWidth: .infinity)
	}

	private func _profileDivider() -> some View {
		Rectangle()
			.fill(.white.opacity(0.18))
			.frame(width: 1, height: 30)
	}

	@ViewBuilder
	private func _accountCard() -> some View {
		NavigationLink {
			ServiceCenterView()
		} label: {
			HStack(spacing: 12) {
				ZStack {
					RoundedRectangle(cornerRadius: 12, style: .continuous)
						.fill(HiboxTheme.softGradient)
						.frame(width: 42, height: 42)
					Image(systemName: "person.crop.circle.fill")
						.font(.system(size: 20, weight: .semibold))
						.foregroundStyle(HiboxTheme.blue)
				}

				VStack(alignment: .leading, spacing: 3) {
					Text("账号与商城")
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(HiboxTheme.text)
					Text("注册、登录、证书兑换与订单")
						.font(.caption2)
						.foregroundStyle(HiboxTheme.secondaryText)
				}

				Spacer(minLength: 0)

				HiboxSoftPill(title: "待接入", color: HiboxTheme.purple)
				Image(systemName: "chevron.right")
					.font(.system(size: 11, weight: .bold))
					.foregroundStyle(HiboxTheme.tertiaryText)
			}
			.hiboxCard(padding: 13)
		}
		.buttonStyle(.plain)
	}
}

// MARK: - Groups
extension SettingsView {
	@ViewBuilder
	private func _certificateGroup() -> some View {
		_menuCard(title: "证书与签名") {
			_linkRow(
				title: "证书管理",
				subtitle: _certificates.isEmpty ? "还没有可用证书" : "\(_certificates.count) 个证书",
				icon: "checkmark.seal.fill",
				color: HiboxTheme.green
			) {
				CertificatesView()
			}
			_rowDivider()
			_linkRow(
				title: "签名设置",
				subtitle: "显示名、Bundle ID、版本",
				icon: "signature",
				color: HiboxTheme.blue
			) {
				ConfigurationView()
			}
			_rowDivider()
			_linkRow(
				title: "安装设置",
				subtitle: "安装方式与服务端",
				icon: "arrow.down.app.fill",
				color: HiboxTheme.purple
			) {
				InstallationView()
			}
		}
	}

	@ViewBuilder
	private func _appGroup() -> some View {
		_menuCard(title: "应用与数据") {
			Button {
				_isSourcesPresenting = true
			} label: {
				_rowLabel(
					title: "软件源",
					subtitle: "添加与管理应用源",
					icon: "globe.desk.fill",
					color: HiboxTheme.blue
				)
			}
			.buttonStyle(.plain)
			_rowDivider()
			_linkRow(
				title: "压缩归档",
				subtitle: "导出格式与压缩级别",
				icon: "archivebox.fill",
				color: HiboxTheme.orange
			) {
				ArchiveView()
			}
			_rowDivider()
			_linkRow(
				title: "清理缓存",
				subtitle: "重置应用数据",
				icon: "trash.fill",
				color: HiboxTheme.secondaryText
			) {
				ResetView()
			}
		}
	}

	@ViewBuilder
	private func _deviceGroup() -> some View {
		_menuCard(title: "设备与工具") {
			_linkRow(
				title: "系统信息",
				subtitle: "设备、存储、系统版本",
				icon: "iphone.gen3",
				color: HiboxTheme.blue
			) {
				SystemInfoView()
			}
			_rowDivider()
			_linkRow(
				title: "设备安全",
				subtitle: "越狱环境检测",
				icon: "lock.shield.fill",
				color: HiboxTheme.green
			) {
				DeviceSecurityView()
			}
			_rowDivider()
			_linkRow(
				title: "网络检测",
				subtitle: "检查签名服务连接",
				icon: "wifi",
				color: HiboxTheme.purple
			) {
				NetworkCheckView()
			}
		}
	}

	@ViewBuilder
	private func _appearanceGroup() -> some View {
		_menuCard(title: "外观") {
			_linkRow(
				title: "外观设置",
				subtitle: "主题色与显示方式",
				icon: "paintbrush.fill",
				color: Color(hex: "#D65A8C")
			) {
				AppearanceView()
			}
			_rowDivider()
			_linkRow(
				title: "App 图标",
				subtitle: "切换桌面图标",
				icon: "app.badge",
				color: HiboxTheme.purple
			) {
				AppIconView(currentIcon: $_currentIcon)
			}
		}
	}

	@ViewBuilder
	private func _aboutGroup() -> some View {
		_menuCard(title: "关于") {
			_linkRow(
				title: "关于艺祥签",
				subtitle: "版本与开源声明",
				icon: "info.circle.fill",
				color: HiboxTheme.blue
			) {
				AboutView()
			}
			if let url = _brand.supportURL {
				_rowDivider()
				Button {
					UIApplication.shared.open(url)
				} label: {
					_rowLabel(
						title: "联系客服",
						subtitle: "使用问题与售后",
						icon: "bubble.left.and.bubble.right.fill",
						color: HiboxTheme.cyan
					)
				}
				.buttonStyle(.plain)
			}
		}
	}
}

// MARK: - Components
extension SettingsView {
	@ViewBuilder
	private func _menuCard<Content: View>(
		title: String,
		@ViewBuilder content: () -> Content
	) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(title)
				.font(.caption.weight(.semibold))
				.foregroundStyle(HiboxTheme.secondaryText)
				.padding(.leading, 4)

			VStack(spacing: 0) {
				content()
			}
			.hiboxCard(padding: 6)
		}
	}

	private func _rowDivider() -> some View {
		Divider()
			.overlay(HiboxTheme.separator)
			.padding(.leading, 58)
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

	private func _rowLabel(
		title: String,
		subtitle: String,
		icon: String,
		color: Color
	) -> some View {
		HStack(spacing: 12) {
			Image(systemName: icon)
				.font(.system(size: 16, weight: .semibold))
				.foregroundStyle(color)
				.frame(width: 36, height: 36)
				.background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(HiboxTheme.text)
				Text(subtitle)
					.font(.caption2)
					.foregroundStyle(HiboxTheme.secondaryText)
			}

			Spacer(minLength: 0)

			Image(systemName: "chevron.right")
				.font(.system(size: 11, weight: .bold))
				.foregroundStyle(HiboxTheme.tertiaryText)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 10)
		.contentShape(Rectangle())
	}
}
