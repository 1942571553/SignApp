//
//  HomeView.swift
//  艺祥签
//
//  首页：品牌、状态、快捷入口和服务器概览
//

import SwiftUI
import CoreData
import NimbleViews
import UniformTypeIdentifiers

struct HomeView: View {
	@StateObject private var _brand = BrandStore.shared
	@StateObject private var _downloadManager = DownloadManager.shared

	@State private var _isImportingPresenting = false
	@State private var _isSourcesPresenting = false
	@State private var _isSyncing = false

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

	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>

	private var _accent: Color { _brand.themeColor }

	var body: some View {
		NBNavigationView("") {
			ScrollView {
				VStack(spacing: 18) {
					_header()
					_stats()
					if let announcement = _brand.announcement {
						_announcement(announcement)
					}
					_quickActions()
					_serviceCard()
					_tipCard()
				}
				.padding(.horizontal, 16)
				.padding(.top, 8)
				.padding(.bottom, 28)
			}
			.background(Color(uiColor: .systemGroupedBackground))
			.scrollIndicators(.hidden)
			.toolbar(.hidden, for: .navigationBar)
			.sheet(isPresented: $_isImportingPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.ipa, .tipa],
					allowsMultipleSelection: true,
					onDocumentsPicked: { urls in
						_importApps(urls)
					}
				)
				.ignoresSafeArea()
			}
			.sheet(isPresented: $_isSourcesPresenting) {
				SourcesView()
			}
		}
	}

	// MARK: - Header
	@ViewBuilder
	private func _header() -> some View {
		VStack(alignment: .leading, spacing: 18) {
			HStack(alignment: .center, spacing: 14) {
				FRAppIconView(size: 62)
					.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

				VStack(alignment: .leading, spacing: 4) {
					Text(_brand.displayName)
						.font(.title2.weight(.bold))
						.foregroundStyle(.white)
					Text(_brand.brand?.subtitle ?? "简易签名")
						.font(.subheadline)
						.foregroundStyle(.white.opacity(0.82))
				}

				Spacer(minLength: 0)

				_statusPill
			}

			Text("本地重签 · 证书不出设备")
				.font(.footnote.weight(.medium))
				.foregroundStyle(.white.opacity(0.9))
		}
		.padding(20)
		.background(
			ZStack(alignment: .topTrailing) {
				LinearGradient(
					colors: [
						_accent,
						_accent.opacity(0.78),
						Color(hex: "#1F6F4A")
					],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)

				Circle()
					.fill(.white.opacity(0.10))
					.frame(width: 168, height: 168)
					.offset(x: 58, y: -70)

				Circle()
					.fill(.white.opacity(0.07))
					.frame(width: 112, height: 112)
					.offset(x: -26, y: 98)
			}
		)
		.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
		.shadow(color: _accent.opacity(0.24), radius: 18, x: 0, y: 10)
	}

	private var _statusPill: some View {
		HStack(spacing: 6) {
			Circle()
				.fill(_statusColor)
				.frame(width: 7, height: 7)
			Text(_statusText)
				.font(.caption2.weight(.semibold))
				.foregroundStyle(.white)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 6)
		.background(.white.opacity(0.18), in: Capsule())
	}

	private var _statusColor: Color {
		if _brand.lastError != nil { return Color(hex: "#FFD166") }
		if _brand.lastSync != nil { return Color(hex: "#72F2B0") }
		return .white.opacity(0.65)
	}

	private var _statusText: String {
		if _brand.lastError != nil { return "离线" }
		if _brand.lastSync != nil { return "服务在线" }
		return "待同步"
	}

	// MARK: - Stats
	@ViewBuilder
	private func _stats() -> some View {
		HStack(spacing: 10) {
			_stat(value: _signedApps.count, title: "已签名", icon: "signature", color: _accent)
			_stat(value: _importedApps.count, title: "应用", icon: "square.grid.2x2.fill", color: Color(hex: "#3E7BFA"))
			_stat(value: _certificates.count, title: "证书", icon: "checkmark.seal.fill", color: Color(hex: "#21A366"))
		}
	}

	private func _stat(value: Int, title: String, icon: String, color: Color) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack {
				Image(systemName: icon)
					.font(.caption.weight(.bold))
					.foregroundStyle(color)
					.frame(width: 26, height: 26)
					.background(color.opacity(0.12), in: Circle())
				Spacer(minLength: 0)
			}

			Text("\(value)")
				.font(.title2.weight(.bold))
				.foregroundStyle(.primary)
				.contentTransition(.numericText())

			Text(title)
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(14)
		.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	}

	// MARK: - Announcement
	@ViewBuilder
	private func _announcement(_ text: String) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 8) {
				Image(systemName: "megaphone.fill")
					.font(.caption.weight(.bold))
					.foregroundStyle(_accent)
				Text("公告")
					.font(.subheadline.weight(.semibold))
				Spacer(minLength: 0)
			}

			Text(text)
				.font(.footnote)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)

			if let url = _brand.supportURL {
				Button {
					UIApplication.shared.open(url)
				} label: {
					Label("联系客服", systemImage: "bubble.left.and.bubble.right.fill")
						.font(.caption.weight(.semibold))
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(16)
		.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
	}

	// MARK: - Quick actions
	@ViewBuilder
	private func _quickActions() -> some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("快捷操作")
				.font(.headline)
				.padding(.horizontal, 2)

			LazyVGrid(
				columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
				spacing: 12
			) {
				Button {
					_isImportingPresenting = true
				} label: {
					_actionCard(title: "导入 IPA", subtitle: "从文件导入应用", icon: "square.and.arrow.down.fill", color: _accent)
				}
				.buttonStyle(.plain)

				NavigationLink {
					CertificatesView()
				} label: {
					_actionCard(title: "证书管理", subtitle: "p12 与描述文件", icon: "checkmark.seal.fill", color: Color(hex: "#21A366"))
				}
				.buttonStyle(.plain)

				Button {
					_isSourcesPresenting = true
				} label: {
					_actionCard(title: "软件源", subtitle: "添加应用源", icon: "globe.desk.fill", color: Color(hex: "#3E7BFA"))
				}
				.buttonStyle(.plain)

				NavigationLink {
					InstallationView()
				} label: {
					_actionCard(title: "安装设置", subtitle: "选择安装方式", icon: "arrow.down.app.fill", color: Color(hex: "#8E5CF7"))
				}
				.buttonStyle(.plain)
			}
		}
	}

	private func _actionCard(title: String, subtitle: String, icon: String, color: Color) -> some View {
		HStack(spacing: 12) {
			Image(systemName: icon)
				.font(.system(size: 18, weight: .semibold))
				.foregroundStyle(.white)
				.frame(width: 42, height: 42)
				.background(
					LinearGradient(colors: [color, color.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing),
					in: RoundedRectangle(cornerRadius: 13, style: .continuous)
				)

			VStack(alignment: .leading, spacing: 3) {
				Text(title)
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(.primary)
				Text(subtitle)
					.font(.caption2)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}

			Spacer(minLength: 0)
		}
		.padding(12)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	}

	// MARK: - Server
	@ViewBuilder
	private func _serviceCard() -> some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(spacing: 8) {
				Image(systemName: "server.rack")
					.font(.caption.weight(.bold))
					.foregroundStyle(_accent)
				Text("服务器")
					.font(.subheadline.weight(.semibold))
				Spacer(minLength: 0)
				if let date = _brand.lastSync {
					Text(date.formatted(date: .abbreviated, time: .shortened))
						.font(.caption2)
						.foregroundStyle(.secondary)
				}
			}

			Text(verbatim: _brand.configURL)
				.font(.caption2)
				.foregroundStyle(.secondary)
				.lineLimit(2)
				.textSelection(.enabled)

			Button {
				_isSyncing = true
				Task {
					await _brand.refresh()
					_isSyncing = false
				}
			} label: {
				HStack {
					Text("同步远程配置")
					Spacer()
					if _isSyncing { ProgressView() }
				}
				.font(.footnote.weight(.semibold))
			}
			.disabled(_isSyncing)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(16)
		.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
	}

	// MARK: - Tip
	@ViewBuilder
	private func _tipCard() -> some View {
		HStack(alignment: .top, spacing: 10) {
			Image(systemName: "lock.shield.fill")
				.font(.caption)
				.foregroundStyle(_accent)
			Text("签名证书和 ipa 都只保存在本机，服务器只负责品牌配置，不会上传你的证书。")
				.font(.caption)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(.horizontal, 4)
	}

	// MARK: - Import
	private func _importApps(_ urls: [URL]) {
		guard !urls.isEmpty else { return }
		for url in urls {
			let id = "FeatherManualDownload_\(UUID().uuidString)"
			let download = _downloadManager.startArchive(from: url, id: id)
			try? _downloadManager.handlePachageFile(url: url, dl: download)
		}
	}
}
