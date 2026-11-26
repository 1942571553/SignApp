//
//  StoreView.swift
//  艺祥签
//
//  ABox 架构的第一页：应用商店。聚合软件源，按分类和关键词浏览。
//

import SwiftUI
import CoreData
import AltSourceKit
import NimbleViews
import UniformTypeIdentifiers

struct StoreView: View {
	@StateObject private var _brand = BrandStore.shared
	@StateObject private var _sourcesViewModel = SourcesViewModel.shared
	@StateObject private var _downloadManager = DownloadManager.shared

	@State private var _apps: [StoreApp] = []
	@State private var _searchText = ""
	@State private var _category: StoreCategory = .hot
	@State private var _isLoading = false
	@State private var _isSourcesPresenting = false
	@State private var _isImportingPresenting = false
	@State private var _isURLPresenting = false
	@State private var _urlString = ""

	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>

	@FetchRequest(
		entity: Signed.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
		animation: .snappy
	) private var _signedApps: FetchedResults<Signed>

	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>

	var body: some View {
		NBNavigationView("") {
			ScrollView {
				VStack(spacing: 14) {
					_header()
					_searchBar()
					_categoryBar()
					_content()
				}
				.padding(.horizontal, 16)
				.padding(.top, 6)
				.padding(.bottom, 30)
			}
			.background(HiboxTheme.background)
			.scrollIndicators(.hidden)
			.toolbar(.hidden, for: .navigationBar)
			.sheet(isPresented: $_isSourcesPresenting) {
				SourcesView()
			}
			.sheet(isPresented: $_isImportingPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.ipa, .tipa],
					allowsMultipleSelection: true,
					onDocumentsPicked: { urls in
						_importFiles(urls)
					}
				)
				.ignoresSafeArea()
			}
			.alert("从 URL 下载", isPresented: $_isURLPresenting) {
				TextField("https://example.com/app.ipa", text: $_urlString)
					.textInputAutocapitalization(.never)
					.keyboardType(.URL)
				Button("取消", role: .cancel) { _urlString = "" }
				Button("下载") {
					if let url = URL(string: _urlString) {
						_ = _downloadManager.startDownload(
							from: url,
							id: "FeatherManualDownload_\(UUID().uuidString)"
						)
					}
					_urlString = ""
				}
			} message: {
				Text("输入 IPA 直链，下载完成后会出现在「已签名」页的待签名列表。")
			}
			.onAppear { _loadApps() }
			.onChange(of: _sources.count) { _ in _loadApps() }
		}
	}
}

// MARK: - Model
extension StoreView {
	struct StoreApp: Identifiable {
		let source: ASRepository
		let sourceURL: URL?
		let app: ASRepository.App

		var id: String { app.currentUniqueId }
	}

	enum StoreCategory: String, CaseIterable {
		case hot
		case apps
		case games
		case tools

		var title: String {
			switch self {
			case .hot:		return "热门"
			case .apps:		return "应用"
			case .games:	return "游戏"
			case .tools:	return "工具"
			}
		}
	}
}

// MARK: - Data
extension StoreView {
	private var _filteredApps: [StoreApp] {
		let base: [StoreApp]

		switch _category {
		case .hot:
			base = Array(_apps.prefix(60))
		case .apps:
			base = _apps.filter { _bucket(for: $0.app) == .apps }
		case .games:
			base = _apps.filter { _bucket(for: $0.app) == .games }
		case .tools:
			base = _apps.filter { _bucket(for: $0.app) == .tools }
		}

		guard !_searchText.isEmpty else { return base }

		let query = _searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		return base.filter { item in
			(item.app.currentName.lowercased().contains(query)
				|| (item.app.id ?? "").lowercased().contains(query)
				|| (item.app.developer ?? "").lowercased().contains(query)
				|| (item.app.localizedDescription ?? item.app.description ?? "").lowercased().contains(query))
		}
	}

	private func _bucket(for app: ASRepository.App) -> StoreCategory {
		let category = (app.category ?? "").lowercased()
		if category.contains("game") || category.contains("游戏") {
			return .games
		}
		if category.contains("util")
			|| category.contains("tool")
			|| category.contains("tweak")
			|| category.contains("jailbreak")
			|| category.contains("插件")
			|| category.contains("工具")
			|| category.contains("越狱") {
			return .tools
		}
		return .apps
	}

	private func _loadApps() {
		guard !_isLoading else { return }
		_isLoading = true

		if _sources.isEmpty && !UserDefaults.standard.bool(forKey: "Hibox.seededSampleSource") {
			UserDefaults.standard.set(true, forKey: "Hibox.seededSampleSource")
			if let url = URL(string: "https://apps.altstore.io") {
				Storage.shared.addSource(
					url,
					name: "示例源 · AltStore",
					identifier: "com.yixiangsign.sample.altstore"
				) { _ in
					DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
						_isLoading = false
						_loadApps()
					}
				}
			}
		}

		Task {
			await _sourcesViewModel.fetchSources(_sources)

			var seen = Set<String>()
			var items: [StoreApp] = []

			for source in _sources {
				guard let repository = _sourcesViewModel.sources[source] else { continue }
				for app in repository.apps {
					let uniqueID = app.currentUniqueId
					guard !seen.contains(uniqueID) else { continue }
					// 示例源里不再展示 AltStore 安装器本身，避免和艺祥签的签名能力混淆
					if ["com.rileytestut.AltStore", "com.rileytestut.AltStore.Beta"].contains(app.id ?? "") {
						continue
					}
					seen.insert(uniqueID)
					items.append(
						StoreApp(source: repository, sourceURL: source.sourceURL, app: app)
					)
				}
			}

			_apps = items
			_isLoading = false
		}
	}
}

// MARK: - Sections
extension StoreView {
	@ViewBuilder
	private func _header() -> some View {
		VStack(alignment: .leading, spacing: 14) {
			HStack(alignment: .center, spacing: 12) {
				FRAppIconView(size: 48)
					.clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

				VStack(alignment: .leading, spacing: 3) {
					Text(_brand.displayName)
						.font(.system(size: 19, weight: .bold))
						.foregroundStyle(.white)
					Text("iOS 签名 · 应用资源商店")
						.font(.caption)
						.foregroundStyle(.white.opacity(0.82))
				}

				Spacer(minLength: 0)

				Menu {
					Button("导入 IPA", systemImage: "square.and.arrow.down") {
						_isImportingPresenting = true
					}
					Button("从 URL 下载", systemImage: "link") {
						_isURLPresenting = true
					}
					Button("添加软件源", systemImage: "plus.circle") {
						_isSourcesPresenting = true
					}
				} label: {
					Image(systemName: "plus")
						.font(.system(size: 16, weight: .bold))
						.foregroundStyle(.white)
						.frame(width: 34, height: 34)
						.background(.white.opacity(0.18), in: Circle())
				}
			}

			HStack(spacing: 18) {
				_headerStat(value: "\(_apps.count)", title: "个应用")
				_headerStat(value: "\(_signedApps.count)", title: "已签名")
				_headerStat(value: "\(_certificates.count)", title: "证书")
				Spacer(minLength: 0)
				Button {
					_isSourcesPresenting = true
				} label: {
					HStack(spacing: 4) {
						Image(systemName: "globe.desk")
							.font(.system(size: 11, weight: .semibold))
						Text("\(_sources.count) 个源")
							.font(.caption2.weight(.semibold))
					}
					.foregroundStyle(.white)
					.padding(.horizontal, 10)
					.padding(.vertical, 5)
					.background(.white.opacity(0.18), in: Capsule())
				}
				.buttonStyle(.plain)
			}
		}
		.padding(18)
		.background(
			ZStack(alignment: .topTrailing) {
				HiboxTheme.gradient
				Circle()
					.fill(.white.opacity(0.12))
					.frame(width: 170, height: 170)
					.offset(x: 60, y: -80)
				Circle()
					.fill(.white.opacity(0.08))
					.frame(width: 100, height: 100)
					.offset(x: -20, y: 100)
			}
		)
		.clipShape(RoundedRectangle(cornerRadius: HiboxTheme.largeRadius, style: .continuous))
		.shadow(color: HiboxTheme.blue.opacity(0.20), radius: 16, x: 0, y: 8)
	}

	private func _headerStat(value: String, title: String) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 3) {
			Text(value)
				.font(.system(size: 17, weight: .bold))
				.foregroundStyle(.white)
			Text(title)
				.font(.caption2)
				.foregroundStyle(.white.opacity(0.74))
		}
	}

	@ViewBuilder
	private func _searchBar() -> some View {
		HStack(spacing: 9) {
			Image(systemName: "magnifyingglass")
				.font(.system(size: 15, weight: .semibold))
				.foregroundStyle(HiboxTheme.tertiaryText)

			TextField("搜索应用、Bundle ID 或开发者", text: $_searchText)
				.font(.subheadline)
				.foregroundStyle(HiboxTheme.text)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()

			if !_searchText.isEmpty {
				Button {
					_searchText = ""
				} label: {
					Image(systemName: "xmark.circle.fill")
						.font(.system(size: 15))
						.foregroundStyle(HiboxTheme.tertiaryText)
				}
				.buttonStyle(.plain)
			}
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 12)
		.background(HiboxTheme.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: 15, style: .continuous)
				.stroke(Color(hex: "#EDF1F7"), lineWidth: 0.8)
		)
	}

	@ViewBuilder
	private func _categoryBar() -> some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 9) {
				ForEach(StoreCategory.allCases, id: \.rawValue) { category in
					Button {
						withAnimation(.easeInOut(duration: 0.18)) {
							_category = category
						}
					} label: {
						Text(category.title)
							.font(.footnote.weight(.semibold))
							.foregroundStyle(_category == category ? .white : HiboxTheme.secondaryText)
							.padding(.horizontal, 16)
							.padding(.vertical, 9)
							.background(
								_category == category
									? AnyShapeStyle(HiboxTheme.gradient)
									: AnyShapeStyle(HiboxTheme.card),
								in: Capsule()
							)
							.overlay(
								Capsule()
									.stroke(
										_category == category ? Color.clear : Color(hex: "#EDF1F7"),
										lineWidth: 0.8
									)
							)
					}
					.buttonStyle(.plain)
				}

				Spacer(minLength: 0)
			}
			.padding(.vertical, 1)
		}
	}

	@ViewBuilder
	private func _content() -> some View {
		if _isLoading && _apps.isEmpty {
			HStack(spacing: 8) {
				ProgressView()
				Text("正在加载软件源…")
					.font(.footnote)
					.foregroundStyle(HiboxTheme.secondaryText)
			}
			.frame(maxWidth: .infinity)
			.padding(.vertical, 60)
		} else if _apps.isEmpty {
			HiboxEmptyState(
				icon: "globe.desk",
				title: _sources.isEmpty ? "还没有软件源" : "暂时没有可用应用",
				message: _sources.isEmpty
					? "添加一个 AltStore / 云趣软件源，就能像应用商店一样浏览和下载。"
					: "软件源里暂时没有可展示的应用，稍后刷新试试。",
				actionTitle: "添加软件源",
				action: { _isSourcesPresenting = true }
			)
		} else if _filteredApps.isEmpty {
			HiboxEmptyState(
				icon: "magnifyingglass",
				title: "没有找到应用",
				message: "换个关键词或分类再试试。",
				actionTitle: "清空搜索",
				action: { _searchText = "" }
			)
		} else {
			VStack(spacing: 10) {
				HStack {
					Text(_category.title)
						.font(.caption.weight(.semibold))
						.foregroundStyle(HiboxTheme.secondaryText)
					Spacer(minLength: 0)
					Text("\(_filteredApps.count) 个")
						.font(.caption2)
						.foregroundStyle(HiboxTheme.tertiaryText)
				}
				.padding(.horizontal, 4)

				LazyVStack(spacing: 10) {
					ForEach(_filteredApps) { item in
						NavigationLink {
							SourceAppsDetailView(
								sourceURL: item.sourceURL,
								source: item.source,
								app: item.app
							)
						} label: {
							_appRow(item)
						}
						.buttonStyle(.plain)
					}
				}
			}
		}
	}
}

// MARK: - Row
extension StoreView {
	private func _appRow(_ item: StoreApp) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(alignment: .top, spacing: 12) {
				HiboxAppIcon(url: item.app.iconURL, name: item.app.currentName, size: 58)

				VStack(alignment: .leading, spacing: 4) {
					Text(item.app.currentName)
						.font(.system(size: 16, weight: .semibold))
						.foregroundStyle(HiboxTheme.text)
						.lineLimit(1)

					HStack(spacing: 5) {
						Text(item.app.currentVersion ?? "—")
							.font(.caption2.weight(.medium))
							.foregroundStyle(HiboxTheme.blue)
						if let date = item.app.versionDate?.date {
							Text("·")
								.font(.caption2)
								.foregroundStyle(HiboxTheme.tertiaryText)
							Text(date.formatted(date: .numeric, time: .omitted))
								.font(.caption2)
								.foregroundStyle(HiboxTheme.secondaryText)
						}
					}

					HStack(spacing: 5) {
						Text(item.app.id ?? item.source.name ?? "")
							.font(.caption2)
							.foregroundStyle(HiboxTheme.secondaryText)
							.lineLimit(1)
						if let size = item.app.size, size > 0 {
							Text("·")
								.font(.caption2)
								.foregroundStyle(HiboxTheme.tertiaryText)
							Text(_sizeText(size))
								.font(.caption2)
								.foregroundStyle(HiboxTheme.secondaryText)
						}
					}
				}

				Spacer(minLength: 0)

				HiboxGradientPill(title: "管理")
			}

			if let desc = item.app.localizedDescription ?? item.app.description ?? item.app.subtitle, !desc.isEmpty {
				Text(desc)
					.font(.caption)
					.foregroundStyle(HiboxTheme.secondaryText)
					.lineLimit(2)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.hiboxCard(padding: 14)
	}

	private func _sizeText(_ bytes: Int64) -> String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		return formatter.string(fromByteCount: bytes)
	}
}

// MARK: - Import
extension StoreView {
	private func _importFiles(_ urls: [URL]) {
		guard !urls.isEmpty else { return }
		for url in urls {
			let id = "FeatherManualDownload_\(UUID().uuidString)"
			let download = _downloadManager.startArchive(from: url, id: id)
			try? _downloadManager.handlePachageFile(url: url, dl: download)
		}
	}
}
