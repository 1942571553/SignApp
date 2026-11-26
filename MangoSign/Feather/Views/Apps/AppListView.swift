//
//  AppListView.swift
//  艺祥签
//
//  四段式结构里的「应用」和「已签名」两个页面。
//  - 应用：品牌卡、统计、快捷操作、已导入的 IPA、软件源
//  - 已签名：签名概览、已签名列表、安装 / 重签 / 导出
//

import SwiftUI
import CoreData
import UIKit
import NimbleViews
import UniformTypeIdentifiers

// MARK: - Mode
enum AppListMode: Equatable {
	case apps
	case signed

	var title: String {
		switch self {
		case .apps:		return "应用"
		case .signed:	return "已签名"
		}
	}

	var listTitle: String {
		switch self {
		case .apps:		return "已导入"
		case .signed:	return "已签名"
		}
	}

	var heroSubtitle: String {
		switch self {
		case .apps:		return "IPA 导入 · 本机签名 · 一键安装"
		case .signed:	return "签名记录 · 安装管理 · 证书状态"
		}
	}
}

// MARK: - View
struct AppListView: View {
	let mode: AppListMode

	@StateObject private var _brand = BrandStore.shared
	@StateObject private var _downloadManager = DownloadManager.shared
	@StateObject private var _updateManager = UpdateManager.shared
	@StateObject private var _sourcesViewModel = SourcesViewModel.shared

	@State private var _selectedInfoAppPresenting: AnyApp?
	@State private var _selectedSigningAppPresenting: AnyApp?
	@State private var _selectedInstallAppPresenting: AnyApp?
	@State private var _isImportingPresenting = false
	@State private var _isDownloadingPresenting = false
	@State private var _isSourcesPresenting = false
	@State private var _alertDownloadString = ""
	@State private var _updateCheckRotation = 0.0
	@State private var _isUpdateCheckCompleteVisible = false
	@State private var _isSyncing = false

	// MARK: Selection State
	@State private var _selectedAppUUIDs: Set<String> = []
	@State private var _editMode: EditMode = .inactive
	@State private var _searchText = ""

	@Namespace private var _namespace

	// MARK: Fetch
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
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>

	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>

	private var _accent: Color { _brand.themeColor }

	private var _isSignedMode: Bool { mode == .signed }

	// MARK: Filtering
	private func _matches(_ app: AppInfoPresentable) -> Bool {
		guard !_searchText.isEmpty else { return true }
		let name = app.name ?? ""
		let identifier = app.identifier ?? ""
		return name.localizedCaseInsensitiveContains(_searchText)
			|| identifier.localizedCaseInsensitiveContains(_searchText)
	}

	private var _filteredSignedApps: [Signed] {
		_signedApps.filter { _matches($0) }
	}

	private var _filteredImportedApps: [Imported] {
		_importedApps.filter { _matches($0) }
	}

	private var _baseApps: [AppInfoPresentable] {
		_isSignedMode
			? _signedApps.map { $0 as AppInfoPresentable }
			: _importedApps.map { $0 as AppInfoPresentable }
	}

	// MARK: Body
	var body: some View {
		NBNavigationView(mode.title) {
			NBListAdaptable {
				_heroSection()
				_statsSection()

				if let announcement = _brand.announcement {
					_announcementSection(announcement)
				}

				_actionSection()

				if !_isSignedMode {
					_sourceSection()
				}

				_appSection()
			}
			.searchable(text: $_searchText, placement: .platform())
			.scrollDismissesKeyboard(.interactively)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					EditButton()
				}

				if _editMode.isEditing {
					NBToolbarButton(
						.localized("Delete"),
						systemImage: "trash",
						isDisabled: _selectedAppUUIDs.isEmpty
					) {
						_bulkDeleteSelectedApps()
					}
				} else {
					ToolbarItem(placement: .topBarTrailing) {
						Button {
							Task { await _checkForUpdates() }
						} label: {
							Image(systemName: _isUpdateCheckCompleteVisible ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
								.rotationEffect(.degrees(_updateCheckRotation))
								.animation(
									_updateManager.isChecking
										? .linear(duration: 0.8).repeatForever(autoreverses: false)
										: .default,
									value: _updateCheckRotation
								)
						}
						.disabled(_updateManager.isChecking)
						.accessibilityLabel(.localized("Check for Updates"))
					}

					NBToolbarMenu(
						systemImage: "plus",
						style: .icon,
						placement: .topBarTrailing
					) {
						_importActions()
					}
				}
			}
			.environment(\.editMode, $_editMode)
			.sheet(item: $_selectedInfoAppPresenting) { app in
				LibraryInfoView(app: app.base)
			}
			.sheet(item: $_selectedInstallAppPresenting) { app in
				InstallPreviewView(app: app.base, isSharing: app.archive)
					.presentationDetents([.height(200)])
					.presentationDragIndicator(.visible)
			}
			.fullScreenCover(item: $_selectedSigningAppPresenting) { app in
				SigningView(app: app.base)
					.compatNavigationTransition(id: app.base.uuid ?? "", ns: _namespace)
			}
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
			.alert(.localized("Import from URL"), isPresented: $_isDownloadingPresenting) {
				TextField(.localized("URL"), text: $_alertDownloadString)
					.textInputAutocapitalization(.never)
				Button(.localized("Cancel"), role: .cancel) { _alertDownloadString = "" }
				Button(.localized("OK")) {
					if let url = URL(string: _alertDownloadString) {
						_ = _downloadManager.startDownload(
							from: url,
							id: "FeatherManualDownload_\(UUID().uuidString)"
						)
					}
				}
			}
			.onReceive(NotificationCenter.default.publisher(for: Notification.Name("Feather.installApp"))) { _ in
				if let latest = _signedApps.first {
					_selectedInstallAppPresenting = AnyApp(base: latest)
				}
			}
			.onChange(of: _editMode) { newMode in
				if newMode == .inactive {
					_selectedAppUUIDs.removeAll()
				}
			}
			.onChange(of: _updateManager.isChecking) { isChecking in
				_handleUpdateCheckStateChange(isChecking)
			}
		}
	}
}

// MARK: - Sections
extension AppListView {
	@ViewBuilder
	private func _heroSection() -> some View {
		Section {
			_hero()
				.listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 2, trailing: 16))
				.listRowBackground(Color.clear)
				.listRowSeparator(.hidden)
		}
	}

	@ViewBuilder
	private func _statsSection() -> some View {
		Section {
			_stats()
				.listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
				.listRowBackground(Color.clear)
				.listRowSeparator(.hidden)
		}
	}

	@ViewBuilder
	private func _announcementSection(_ text: String) -> some View {
		Section {
			_announcement(text)
				.listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
				.listRowBackground(Color.clear)
				.listRowSeparator(.hidden)
		}
	}

	@ViewBuilder
	private func _actionSection() -> some View {
		Section {
			_quickActions()
				.listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
				.listRowBackground(Color.clear)
				.listRowSeparator(.hidden)
		}
	}

	@ViewBuilder
	private func _sourceSection() -> some View {
		if !_sources.isEmpty {
			NBSection("软件源", secondary: _sources.count.description) {
				NavigationLink {
					SourceAppsView(object: Array(_sources), viewModel: _sourcesViewModel)
				} label: {
					_sourceRow(
						title: "浏览软件源",
						subtitle: "来自 \(_sources.count) 个源的应用",
						icon: "globe.desk.fill",
						color: Color(hex: "#3E7BFA")
					)
				}
				.buttonStyle(.plain)

				Button {
					_isSourcesPresenting = true
				} label: {
					_sourceRow(
						title: "管理软件源",
						subtitle: "添加、删除和刷新源",
						icon: "link.badge.plus",
						color: Color(hex: "#8E5CF7")
					)
				}
				.buttonStyle(.plain)
			}
		}
	}

	@ViewBuilder
	private func _appSection() -> some View {
		if _isSignedMode {
			if _filteredSignedApps.isEmpty {
				Section {
					_emptyCard()
						.listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
						.listRowBackground(Color.clear)
						.listRowSeparator(.hidden)
				}
			} else {
				NBSection("已签名", secondary: _filteredSignedApps.count.description) {
					ForEach(_filteredSignedApps, id: \.uuid) { app in
						LibraryCellView(
							app: app,
							selectedInfoAppPresenting: $_selectedInfoAppPresenting,
							selectedSigningAppPresenting: $_selectedSigningAppPresenting,
							selectedInstallAppPresenting: $_selectedInstallAppPresenting,
							selectedAppUUIDs: $_selectedAppUUIDs
						)
						.compatMatchedTransitionSource(id: app.uuid ?? "", ns: _namespace)
					}
				}
			}
		} else {
			if _filteredImportedApps.isEmpty {
				Section {
					_emptyCard()
						.listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
						.listRowBackground(Color.clear)
						.listRowSeparator(.hidden)
				}
			} else {
				NBSection("已导入", secondary: _filteredImportedApps.count.description) {
					ForEach(_filteredImportedApps, id: \.uuid) { app in
						LibraryCellView(
							app: app,
							selectedInfoAppPresenting: $_selectedInfoAppPresenting,
							selectedSigningAppPresenting: $_selectedSigningAppPresenting,
							selectedInstallAppPresenting: $_selectedInstallAppPresenting,
							selectedAppUUIDs: $_selectedAppUUIDs
						)
						.compatMatchedTransitionSource(id: app.uuid ?? "", ns: _namespace)
					}
				}
			}
		}
	}
}

// MARK: - Header
extension AppListView {
	@ViewBuilder
	private func _hero() -> some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack(alignment: .center, spacing: 13) {
				FRAppIconView(size: 58)
					.clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

				VStack(alignment: .leading, spacing: 4) {
					Text(_brand.displayName)
						.font(.title3.weight(.bold))
						.foregroundStyle(.white)
					Text(mode.heroSubtitle)
						.font(.caption)
						.foregroundStyle(.white.opacity(0.82))
						.lineLimit(1)
				}

				Spacer(minLength: 0)

				_statusPill
			}

			HStack(spacing: 7) {
				Image(systemName: _isSignedMode ? "checkmark.seal.fill" : "lock.shield.fill")
					.font(.caption2)
				Text(_isSignedMode ? "签名文件与证书只保存在本机" : "支持 IPA / TIPA，签名过程不上传证书")
					.font(.caption2)
			}
			.foregroundStyle(.white.opacity(0.88))
		}
		.padding(18)
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
					.frame(width: 170, height: 170)
					.offset(x: 62, y: -78)

				Circle()
					.fill(.white.opacity(0.07))
					.frame(width: 108, height: 108)
					.offset(x: -18, y: 92)
			}
		)
		.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
		.shadow(color: _accent.opacity(0.22), radius: 18, x: 0, y: 10)
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
		if _isSignedMode {
			return _certificates.isEmpty ? Color(hex: "#FFD166") : Color(hex: "#72F2B0")
		}
		if _brand.lastError != nil { return Color(hex: "#FFD166") }
		if _brand.lastSync != nil { return Color(hex: "#72F2B0") }
		return .white.opacity(0.65)
	}

	private var _statusText: String {
		if _isSignedMode {
			return _certificates.isEmpty ? "未导入证书" : "证书就绪"
		}
		if _brand.lastError != nil { return "离线" }
		if _brand.lastSync != nil { return "服务在线" }
		return "待同步"
	}

	@ViewBuilder
	private func _stats() -> some View {
		HStack(spacing: 10) {
			_stat(value: _signedApps.count, title: "已签名", icon: "checkmark.seal.fill", color: _accent)
			_stat(value: _importedApps.count, title: "应用", icon: "square.grid.2x2.fill", color: Color(hex: "#3E7BFA"))
			_stat(value: _certificates.count, title: "证书", icon: "person.badge.key.fill", color: Color(hex: "#21A366"))
		}
	}

	private func _stat(value: Int, title: String, icon: String, color: Color) -> some View {
		VStack(alignment: .leading, spacing: 9) {
			Image(systemName: icon)
				.font(.caption.weight(.bold))
				.foregroundStyle(color)
				.frame(width: 26, height: 26)
				.background(color.opacity(0.12), in: Circle())

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
		.background(
			Color(uiColor: .secondarySystemGroupedBackground),
			in: RoundedRectangle(cornerRadius: 18, style: .continuous)
		)
	}

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

			HStack(spacing: 14) {
				if let url = _brand.supportURL {
					Button {
						UIApplication.shared.open(url)
					} label: {
						Label("联系客服", systemImage: "bubble.left.and.bubble.right.fill")
							.font(.caption.weight(.semibold))
					}
				}

				Button {
					_isSyncing = true
					Task {
						await _brand.refresh()
						_isSyncing = false
					}
				} label: {
					if _isSyncing {
						ProgressView()
							.controlSize(.mini)
					} else {
						Label("刷新", systemImage: "arrow.clockwise")
							.font(.caption.weight(.semibold))
					}
				}
				.disabled(_isSyncing)
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
	private func _quickActions() -> some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Text("快捷操作")
					.font(.headline)
				Spacer(minLength: 0)
				Text(_isSignedMode ? "签名与安装" : "导入与签名")
					.font(.caption2)
					.foregroundStyle(.secondary)
			}

			LazyVGrid(
				columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
				spacing: 12
			) {
				Button {
					_isImportingPresenting = true
				} label: {
					_actionCard(
						title: _isSignedMode ? "导入并签名" : "导入 IPA",
						subtitle: _isSignedMode ? "从文件选择安装包" : "支持 IPA 与 TIPA",
						icon: "square.and.arrow.down.fill",
						color: _accent
					)
				}
				.buttonStyle(.plain)

				NavigationLink {
					CertificatesView()
				} label: {
					_actionCard(
						title: "证书管理",
						subtitle: _certificates.isEmpty ? "还没有可用证书" : "\(_certificates.count) 个证书",
						icon: "checkmark.seal.fill",
						color: Color(hex: "#21A366")
					)
				}
				.buttonStyle(.plain)

				if _isSignedMode {
					NavigationLink {
						InstallationView()
					} label: {
						_actionCard(
							title: "安装设置",
							subtitle: "选择安装方式",
							icon: "arrow.down.app.fill",
							color: Color(hex: "#8E5CF7")
						)
					}
					.buttonStyle(.plain)

					NavigationLink {
						ArchiveView()
					} label: {
						_actionCard(
							title: "导出归档",
							subtitle: "压缩级别与导出",
							icon: "archivebox.fill",
							color: Color(hex: "#C77B30")
						)
					}
					.buttonStyle(.plain)
				} else {
					Button {
						_isSourcesPresenting = true
					} label: {
						_actionCard(
							title: "软件源",
							subtitle: _sources.isEmpty ? "添加第一个源" : "\(_sources.count) 个源",
							icon: "globe.desk.fill",
							color: Color(hex: "#3E7BFA")
						)
					}
					.buttonStyle(.plain)

					NavigationLink {
						ConfigurationView()
					} label: {
						_actionCard(
							title: "签名设置",
							subtitle: "显示名 / Bundle ID",
							icon: "signature",
							color: _accent
						)
					}
					.buttonStyle(.plain)
				}
			}
		}
		.padding(16)
		.background(
			Color(uiColor: .secondarySystemGroupedBackground),
			in: RoundedRectangle(cornerRadius: 22, style: .continuous)
		)
	}

	private func _actionCard(title: String, subtitle: String, icon: String, color: Color) -> some View {
		HStack(spacing: 11) {
			Image(systemName: icon)
				.font(.system(size: 17, weight: .semibold))
				.foregroundStyle(.white)
				.frame(width: 40, height: 40)
				.background(
					LinearGradient(
						colors: [color, color.opacity(0.72)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					),
					in: RoundedRectangle(cornerRadius: 12, style: .continuous)
				)

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

			Spacer(minLength: 0)
		}
		.padding(11)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			Color(uiColor: .tertiarySystemGroupedBackground),
			in: RoundedRectangle(cornerRadius: 16, style: .continuous)
		)
	}
}

// MARK: - Rows & Empty
extension AppListView {
	private func _sourceRow(title: String, subtitle: String, icon: String, color: Color) -> some View {
		HStack(spacing: 13) {
			Image(systemName: icon)
				.font(.system(size: 17, weight: .semibold))
				.foregroundStyle(color)
				.frame(width: 38, height: 38)
				.background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

			VStack(alignment: .leading, spacing: 3) {
				Text(title)
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(.primary)
				Text(subtitle)
					.font(.caption2)
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 0)

			Image(systemName: "chevron.right")
				.font(.caption2.weight(.semibold))
				.foregroundStyle(.tertiary)
		}
		.padding(.vertical, 4)
		.contentShape(Rectangle())
	}

	@ViewBuilder
	private func _emptyCard() -> some View {
		VStack(spacing: 14) {
			ZStack {
				Circle()
					.fill(_accent.opacity(0.12))
					.frame(width: 74, height: 74)
				Image(systemName: _isSignedMode ? "checkmark.seal.fill" : "square.and.arrow.down.fill")
					.font(.system(size: 28, weight: .semibold))
					.foregroundStyle(_accent)
			}

			Text(_isSignedMode ? "还没有签名记录" : "还没有导入应用")
				.font(.headline)
			Text(_isSignedMode ? "在「应用」页导入 IPA，完成签名后会出现在这里。" : "从文件或软件源导入 IPA，就可以开始本机签名。")
				.font(.footnote)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)

			Button {
				_isImportingPresenting = true
			} label: {
				Label(_isSignedMode ? "导入并签名" : "导入第一个 IPA", systemImage: "plus")
					.font(.footnote.weight(.semibold))
					.foregroundStyle(.white)
					.padding(.horizontal, 16)
					.padding(.vertical, 10)
					.background(_accent, in: Capsule())
			}
			.buttonStyle(.plain)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 26)
		.padding(.horizontal, 18)
		.background(
			Color(uiColor: .secondarySystemGroupedBackground),
			in: RoundedRectangle(cornerRadius: 22, style: .continuous)
		)
	}
}

// MARK: - Actions
extension AppListView {
	@ViewBuilder
	private func _importActions() -> some View {
		Button(.localized("Import from Files"), systemImage: "folder") {
			_isImportingPresenting = true
		}
		Button(.localized("Import from URL"), systemImage: "globe") {
			_isDownloadingPresenting = true
		}
	}

	private func _importApps(_ urls: [URL]) {
		guard !urls.isEmpty else { return }
		for url in urls {
			let id = "FeatherManualDownload_\(UUID().uuidString)"
			let download = _downloadManager.startArchive(from: url, id: id)
			try? _downloadManager.handlePachageFile(url: url, dl: download)
		}
	}

	private func _bulkDeleteSelectedApps() {
		let selectedApps = _baseApps.filter { app in
			guard let uuid = app.uuid else { return false }
			return _selectedAppUUIDs.contains(uuid)
		}

		for app in selectedApps {
			Storage.shared.deleteApp(for: app)
		}

		_selectedAppUUIDs.removeAll()
	}

	private func _checkForUpdates() async {
		let localApps = _signedApps.map { $0 as AppInfoPresentable } + _importedApps.map { $0 as AppInfoPresentable }
		await _updateManager.checkForUpdates(
			sources: Array(_sources),
			localApps: localApps
		)
	}

	private func _handleUpdateCheckStateChange(_ isChecking: Bool) {
		if isChecking {
			_isUpdateCheckCompleteVisible = false
			_updateCheckRotation = 0
			withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
				_updateCheckRotation = 360
			}
		} else {
			withAnimation(.none) {
				_updateCheckRotation = 0
			}

			_isUpdateCheckCompleteVisible = true
			Task { @MainActor in
				try? await Task.sleep(nanoseconds: 900_000_000)
				if !_updateManager.isChecking {
					_isUpdateCheckCompleteVisible = false
				}
			}
		}
	}
}
