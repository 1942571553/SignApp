//
//  ToolsView.swift
//  艺祥签
//
//  工具页：证书、签名选项、安装、清理等入口
//

import SwiftUI
import NimbleViews

struct ToolsView: View {
	@StateObject private var _brand = BrandStore.shared
	@State private var _isSourcesPresenting = false

	private var _accent: Color { _brand.themeColor }

	var body: some View {
		NBNavigationView("工具") {
			ScrollView {
				VStack(spacing: 18) {
					_intro()

					LazyVGrid(
						columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
						spacing: 12
					) {
						_toolLink(title: "证书管理", subtitle: "导入 p12 / 描述文件", icon: "checkmark.seal.fill", color: Color(hex: "#21A366")) {
							CertificatesView()
						}

						Button {
							_isSourcesPresenting = true
						} label: {
							_toolCard(title: "软件源", subtitle: "添加应用源", icon: "globe.desk.fill", color: Color(hex: "#3E7BFA"))
						}
						.buttonStyle(.plain)

						_toolLink(title: "签名设置", subtitle: "显示名 / Bundle ID", icon: "signature", color: _accent) {
							ConfigurationView()
						}

						_toolLink(title: "安装设置", subtitle: "服务端 / idevice", icon: "arrow.down.app.fill", color: Color(hex: "#8E5CF7")) {
							InstallationView()
						}

						_toolLink(title: "压缩归档", subtitle: "导出与压缩级别", icon: "archivebox.fill", color: Color(hex: "#C77B30")) {
							ArchiveView()
						}

						_toolLink(title: "外观设置", subtitle: "主题色与显示", icon: "paintbrush.fill", color: Color(hex: "#D65A8C")) {
							AppearanceView()
						}

						_toolLink(title: "清理缓存", subtitle: "重置应用数据", icon: "trash.fill", color: Color(hex: "#6B7280")) {
							ResetView()
						}

						_toolLink(title: "关于艺祥签", subtitle: "版本与开源声明", icon: "info.circle.fill", color: Color(hex: "#0F766E")) {
							AboutView()
						}
					}
				}
				.padding(.horizontal, 16)
				.padding(.top, 8)
				.padding(.bottom, 28)
			}
			.background(Color(uiColor: .systemGroupedBackground))
			.scrollIndicators(.hidden)
			.sheet(isPresented: $_isSourcesPresenting) {
				SourcesView()
			}
		}
	}

	@ViewBuilder
	private func _intro() -> some View {
		HStack(spacing: 14) {
			Image(systemName: "wrench.and.screwdriver.fill")
				.font(.system(size: 22, weight: .semibold))
				.foregroundStyle(.white)
				.frame(width: 48, height: 48)
				.background(
					LinearGradient(colors: [_accent, _accent.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing),
					in: RoundedRectangle(cornerRadius: 14, style: .continuous)
				)

			VStack(alignment: .leading, spacing: 4) {
				Text("签名工具箱")
					.font(.headline)
				Text("证书、描述文件、安装方式和清理都在这里")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 0)
		}
		.padding(16)
		.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
				Text(subtitle)
					.font(.caption2)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(14)
		.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	}
}
