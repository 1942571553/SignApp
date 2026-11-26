//
//  ToolsView.swift
//  艺祥签
//
//  工具页：按 ABox / 嗨签的工具箱结构分组
//

import SwiftUI
import NimbleViews
import UIKit

struct ToolsView: View {
	@StateObject private var _brand = BrandStore.shared
	@State private var _isSourcesPresenting = false
	@State private var _currentIcon: String? = UIApplication.shared.alternateIconName

	private var _accent: Color { _brand.themeColor }

	var body: some View {
		NBNavigationView("工具") {
			ScrollView {
				VStack(spacing: 18) {
					_hero()
					_signSection()
					_appSection()
					_deviceSection()
					_moreSection()
					_tip()
				}
				.padding(.horizontal, 16)
				.padding(.top, 8)
				.padding(.bottom, 30)
			}
			.background(Color(uiColor: .systemGroupedBackground))
			.scrollIndicators(.hidden)
			.sheet(isPresented: $_isSourcesPresenting) {
				SourcesView()
			}
		}
	}

	// MARK: - Hero
	@ViewBuilder
	private func _hero() -> some View {
		HStack(spacing: 14) {
			Image(systemName: "wrench.and.screwdriver.fill")
				.font(.system(size: 23, weight: .semibold))
				.foregroundStyle(.white)
				.frame(width: 54, height: 54)
				.background(
					LinearGradient(
						colors: [_accent, _accent.opacity(0.72)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					),
					in: RoundedRectangle(cornerRadius: 15, style: .continuous)
				)

			VStack(alignment: .leading, spacing: 4) {
				Text("签名工具箱")
					.font(.title3.weight(.bold))
				Text("证书、签名、安装与设备状态都在这里")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 0)
		}
		.padding(18)
		.background {
			ZStack(alignment: .topTrailing) {
				Color(uiColor: .secondarySystemGroupedBackground)
				Circle()
					.fill(_accent.opacity(0.08))
					.frame(width: 150, height: 150)
					.offset(x: 54, y: -70)
			}
		}
		.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
	}

	// MARK: - Sections
	@ViewBuilder
	private func _signSection() -> some View {
		_group(title: "证书与签名", subtitle: "签名流程的核心设置") {
			_toolLink(title: "证书管理", subtitle: "导入 p12 / 描述文件", icon: "checkmark.seal.fill", color: Color(hex: "#21A366")) {
				CertificatesView()
			}
			_toolLink(title: "签名设置", subtitle: "显示名 / Bundle ID", icon: "signature", color: _accent) {
				ConfigurationView()
			}
			_toolLink(title: "安装设置", subtitle: "服务端 / idevice", icon: "arrow.down.app.fill", color: Color(hex: "#8E5CF7")) {
				InstallationView()
			}
			_toolLink(title: "压缩归档", subtitle: "导出与压缩级别", icon: "archivebox.fill", color: Color(hex: "#C77B30")) {
				ArchiveView()
			}
		}
	}

	@ViewBuilder
	private func _appSection() -> some View {
		_group(title: "应用与来源", subtitle: "导入应用、管理来源") {
			Button {
				_isSourcesPresenting = true
			} label: {
				_toolCard(title: "软件源", subtitle: "添加与管理应用源", icon: "globe.desk.fill", color: Color(hex: "#3E7BFA"))
			}
			.buttonStyle(.plain)

			Button {
				_openDocuments()
			} label: {
				_toolCard(title: "文件目录", subtitle: "在文件中查看 IPA", icon: "folder.fill", color: Color(hex: "#0F766E"))
			}
			.buttonStyle(.plain)

			_toolLink(title: "清理缓存", subtitle: "重置应用数据", icon: "trash.fill", color: Color(hex: "#6B7280")) {
				ResetView()
			}
			_toolLink(title: "外观设置", subtitle: "主题色与显示", icon: "paintbrush.fill", color: Color(hex: "#D65A8C")) {
				AppearanceView()
			}
		}
	}

	@ViewBuilder
	private func _deviceSection() -> some View {
		_group(title: "设备与系统", subtitle: "本机状态与连接检测") {
			_toolLink(title: "系统信息", subtitle: "设备、存储、版本", icon: "iphone.gen3", color: Color(hex: "#2F6FED")) {
				SystemInfoView()
			}
			_toolLink(title: "设备安全", subtitle: "越狱环境检测", icon: "lock.shield.fill", color: Color(hex: "#21A366")) {
				DeviceSecurityView()
			}
			_toolLink(title: "网络检测", subtitle: "检查签名服务连接", icon: "wifi", color: Color(hex: "#8E5CF7")) {
				NetworkCheckView()
			}
			_toolLink(title: "App 图标", subtitle: "切换桌面图标", icon: "app.badge", color: Color(hex: "#D65A8C")) {
				AppIconView(currentIcon: $_currentIcon)
			}
		}
	}

	@ViewBuilder
	private func _moreSection() -> some View {
		_group(title: "更多", subtitle: "服务与说明") {
			_toolLink(title: "账号与商城", subtitle: "余额、证书与授权", icon: "cart.fill", color: Color(hex: "#E08A1E")) {
				ServiceCenterView()
			}
			_toolLink(title: "关于艺祥签", subtitle: "版本与开源声明", icon: "info.circle.fill", color: _accent) {
				AboutView()
			}
			if let url = _brand.supportURL {
				Button {
					UIApplication.shared.open(url)
				} label: {
					_toolCard(title: "联系客服", subtitle: "使用问题与售后", icon: "bubble.left.and.bubble.right.fill", color: Color(hex: "#3E7BFA"))
				}
				.buttonStyle(.plain)
			}
		}
	}

	// MARK: - Components
	@ViewBuilder
	private func _group<Content: View>(
		title: String,
		subtitle: String,
		@ViewBuilder content: () -> Content
	) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(alignment: .firstTextBaseline) {
				Text(title)
					.font(.title3.weight(.bold))
				Spacer(minLength: 0)
				Text(subtitle)
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
			.padding(.horizontal, 2)

			LazyVGrid(
				columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
				spacing: 12
			) {
				content()
			}
		}
	}

	@ViewBuilder
	private func _toolLink<Destination: View>(
		title: String,
		subtitle: String,
		icon: String,
		color: Color,
		@ViewBuilder destination: () -> Destination
	) -> some View {
		NavigationLink {
			destination()
		} label: {
			_toolCard(title: title, subtitle: subtitle, icon: icon, color: color)
		}
		.buttonStyle(.plain)
	}

	private func _toolCard(title: String, subtitle: String, icon: String, color: Color) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Image(systemName: icon)
					.font(.system(size: 17, weight: .semibold))
					.foregroundStyle(color)
					.frame(width: 38, height: 38)
					.background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
				Spacer(minLength: 0)
				Image(systemName: "chevron.right")
					.font(.caption2.weight(.semibold))
					.foregroundStyle(.tertiary)
			}

			VStack(alignment: .leading, spacing: 3) {
				Text(title)
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(.primary)
					.lineLimit(1)
				Text(subtitle)
					.font(.caption2)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(14)
		.background(
			Color(uiColor: .secondarySystemGroupedBackground),
			in: RoundedRectangle(cornerRadius: 18, style: .continuous)
		)
	}

	@ViewBuilder
	private func _tip() -> some View {
		HStack(alignment: .top, spacing: 10) {
			Image(systemName: "lock.shield.fill")
				.font(.caption)
				.foregroundStyle(_accent)
			Text("证书和 IPA 只保存在本机，服务器仅提供品牌配置，不会上传你的证书。")
				.font(.caption)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(.horizontal, 4)
	}

	private func _openDocuments() {
		guard let url = URL.documentsDirectory.toSharedDocumentsURL() else { return }
		UIApplication.shared.open(url)
	}
}
