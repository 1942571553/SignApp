//
//  SignedAppsView.swift
//  艺祥签
//
//  ABox 架构的第二页：已签名。上方显示待签名的导入应用，下方是签名结果。
//

import SwiftUI
import CoreData
import NimbleViews
import NimbleExtensions
import UniformTypeIdentifiers

struct SignedAppsView: View {
	@StateObject private var _downloadManager = DownloadManager.shared

	@State private var _searchText = ""
	@State private var _selectedInfoApp: AnyApp?
	@State private var _selectedSigningApp: AnyApp?
	@State private var _selectedInstallApp: AnyApp?
	@State private var _isImportingPresenting = false

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

	var body: some View {
		NBNavigationView("") {
			ScrollView {
				VStack(spacing: 14) {
					_header()
					_searchBar()
					_content()
				}
				.padding(.horizontal, 16)
				.padding(.top, 6)
				.padding(.bottom, 30)
			}
			.background(HiboxTheme.background)
			.scrollIndicators(.hidden)
			.toolbar(.hidden, for: .navigationBar)
			.sheet(item: $_selectedInfoApp) { app in
				LibraryInfoView(app: app.base)
			}
			.sheet(item: $_selectedInstallApp) { app in
				InstallPreviewView(app: app.base, isSharing: app.archive)
					.presentationDetents([.height(220)])
					.presentationDragIndicator(.visible)
			}
			.fullScreenCover(item: $_selectedSigningApp) { app in
				SigningView(app: app.base)
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
		}
	}
}

// MARK: - Filter
extension SignedAppsView {
	private var _filteredSigned: [Signed] {
		guard !_searchText.isEmpty else { return Array(_signedApps) }
		return _signedApps.filter {
			($0.name ?? "").localizedCaseInsensitiveContains(_searchText)
				|| ($0.identifier ?? "").localizedCaseInsensitiveContains(_searchText)
		}
	}

	private var _filteredImported: [Imported] {
		guard !_searchText.isEmpty else { return Array(_importedApps) }
		return _importedApps.filter {
			($0.name ?? "").localizedCaseInsensitiveContains(_searchText)
				|| ($0.identifier ?? "").localizedCaseInsensitiveContains(_searchText)
		}
	}
}

// MARK: - Sections
extension SignedAppsView {
	@ViewBuilder
	private func _header() -> some View {
		VStack(alignment: .leading, spacing: 14) {
			HStack(alignment: .center, spacing: 12) {
				ZStack {
					Circle()
						.fill(.white.opacity(0.20))
						.frame(width: 48, height: 48)
					Image(systemName: "checkmark.seal.fill")
						.font(.system(size: 23, weight: .semibold))
						.foregroundStyle(.white)
				}

				VStack(alignment: .leading, spacing: 3) {
					Text("已签名")
						.font(.system(size: 19, weight: .bold))
						.foregroundStyle(.white)
					Text("签名完成的应用与待处理文件")
						.font(.caption)
						.foregroundStyle(.white.opacity(0.82))
				}

				Spacer(minLength: 0)

				Button {
					_isImportingPresenting = true
				} label: {
					Image(systemName: "plus")
						.font(.system(size: 16, weight: .bold))
						.foregroundStyle(.white)
						.frame(width: 34, height: 34)
						.background(.white.opacity(0.18), in: Circle())
				}
				.buttonStyle(.plain)
			}

			HStack(spacing: 18) {
				_headerStat(value: "\(_signedApps.count)", title: "已签名")
				_headerStat(value: "\(_importedApps.count)", title: "待签名")
				_headerStat(value: "\(_certificates.count)", title: "证书")
				Spacer(minLength: 0)
			}
		}
		.padding(18)
		.background(
			ZStack(alignment: .topTrailing) {
				HiboxTheme.gradient
				Circle()
					.fill(.white.opacity(0.12))
					.frame(width: 160, height: 160)
					.offset(x: 55, y: -85)
			}
		)
		.clipShape(RoundedRectangle(cornerRadius: HiboxTheme.largeRadius, style: .continuous))
		.shadow(color: HiboxTheme.purple.opacity(0.18), radius: 16, x: 0, y: 8)
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

			TextField("搜索已签名应用", text: $_searchText)
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
	private func _content() -> some View {
		if _filteredSigned.isEmpty && _filteredImported.isEmpty {
			HiboxEmptyState(
				icon: "checkmark.seal",
				title: _searchText.isEmpty ? "还没有已签名应用" : "没有找到应用",
				message: _searchText.isEmpty
					? "在「应用」页下载，或从文件导入 IPA，然后在这里完成签名。"
					: "换个关键词再试试。",
				actionTitle: _searchText.isEmpty ? "导入 IPA" : nil,
				action: _searchText.isEmpty ? { _isImportingPresenting = true } : nil
			)
		} else {
			VStack(spacing: 16) {
				if !_filteredImported.isEmpty {
					VStack(spacing: 10) {
						HiboxSectionHeader(
							title: "待签名",
							subtitle: "\(_filteredImported.count) 个文件",
							trailing: "长按可删除"
						)

						LazyVStack(spacing: 10) {
							ForEach(_filteredImported, id: \.uuid) { app in
								_importedRow(app)
							}
						}
					}
				}

				if !_filteredSigned.isEmpty {
					VStack(spacing: 10) {
						HiboxSectionHeader(
							title: "已签名",
							subtitle: "\(_filteredSigned.count) 个应用",
							trailing: "点击安装"
						)

						LazyVStack(spacing: 10) {
							ForEach(_filteredSigned, id: \.uuid) { app in
								_signedRow(app)
							}
						}
					}
				}
			}
		}
	}
}

// MARK: - Rows
extension SignedAppsView {
	@ViewBuilder
	private func _importedRow(_ app: Imported) -> some View {
		HStack(spacing: 12) {
			FRAppIconView(app: app, size: 54)

			VStack(alignment: .leading, spacing: 4) {
				Text(app.name ?? "未命名应用")
					.font(.system(size: 15, weight: .semibold))
					.foregroundStyle(HiboxTheme.text)
					.lineLimit(1)
				Text("\(app.version ?? "—") · \(app.identifier ?? "")")
					.font(.caption2)
					.foregroundStyle(HiboxTheme.secondaryText)
					.lineLimit(1)
				HiboxSoftPill(
					title: "待签名",
					color: HiboxTheme.orange,
					icon: "clock.fill"
				)
			}

			Spacer(minLength: 0)

			Button {
				_selectedSigningApp = AnyApp(base: app)
			} label: {
				Text("签名")
					.font(.caption.weight(.semibold))
					.foregroundStyle(.white)
					.padding(.horizontal, 14)
					.padding(.vertical, 8)
					.background(HiboxTheme.gradient, in: Capsule())
		}
			.buttonStyle(.plain)
		}
		.hiboxCard(padding: 13)
		.contextMenu {
			Button("开始签名", systemImage: "signature") {
				_selectedSigningApp = AnyApp(base: app)
			}
			Button("查看信息", systemImage: "info.circle") {
				_selectedInfoApp = AnyApp(base: app)
			}
			Button("删除", systemImage: "trash", role: .destructive) {
				Storage.shared.deleteApp(for: app)
			}
		}
	}

	@ViewBuilder
	private func _signedRow(_ app: Signed) -> some View {
		let cert = Storage.shared.getCertificate(from: app)
		let expiration = cert?.expiration?.expirationInfo()

		VStack(alignment: .leading, spacing: 10) {
			HStack(alignment: .top, spacing: 12) {
				FRAppIconView(app: app, size: 54)

				VStack(alignment: .leading, spacing: 4) {
					Text(app.name ?? "未命名应用")
						.font(.system(size: 15, weight: .semibold))
						.foregroundStyle(HiboxTheme.text)
						.lineLimit(1)

					HStack(spacing: 5) {
						Text(app.version ?? "—")
							.font(.caption2.weight(.medium))
							.foregroundStyle(HiboxTheme.blue)
						if let date = app.date {
							Text("·")
								.font(.caption2)
								.foregroundStyle(HiboxTheme.tertiaryText)
							Text(date.formatted(date: .numeric, time: .omitted))
								.font(.caption2)
								.foregroundStyle(HiboxTheme.secondaryText)
						}
					}

					Text(app.identifier ?? "")
						.font(.caption2)
						.foregroundStyle(HiboxTheme.secondaryText)
						.lineLimit(1)
				}

				Spacer(minLength: 0)

				VStack(spacing: 8) {
					Button {
						_selectedInstallApp = AnyApp(base: app)
					} label: {
						HiboxGradientPill(title: "安装", icon: "arrow.down.to.line")
					}
					.buttonStyle(.plain)

					Button {
						_selectedInfoApp = AnyApp(base: app)
					} label: {
						Image(systemName: "info.circle")
							.font(.system(size: 17, weight: .regular))
							.foregroundStyle(HiboxTheme.secondaryText)
							.frame(width: 28, height: 24)
					}
					.buttonStyle(.plain)
				}
			}

			Divider()
				.overlay(HiboxTheme.separator)

			HStack(spacing: 6) {
				Image(systemName: "checkmark.seal.fill")
					.font(.system(size: 11, weight: .semibold))
					.foregroundStyle(HiboxTheme.green)

				Text("签名证书：\(cert?.nickname ?? "未绑定证书")")
					.font(.caption2)
					.foregroundStyle(HiboxTheme.secondaryText)
					.lineLimit(1)

				Spacer(minLength: 0)

				if let expiration {
					Text(expiration.formatted)
						.font(.caption2.weight(.medium))
						.foregroundStyle(expiration.color)
				}
			}
		}
		.hiboxCard(padding: 13)
		.contextMenu {
			Button("安装", systemImage: "arrow.down.to.line") {
				_selectedInstallApp = AnyApp(base: app)
			}
			Button("重新签名", systemImage: "signature") {
				_selectedSigningApp = AnyApp(base: app)
			}
			Button("查看信息", systemImage: "info.circle") {
				_selectedInfoApp = AnyApp(base: app)
			}
			Button("删除", systemImage: "trash", role: .destructive) {
				Storage.shared.deleteApp(for: app)
			}
		}
	}
}

// MARK: - Import
extension SignedAppsView {
	private func _importFiles(_ urls: [URL]) {
		guard !urls.isEmpty else { return }
		for url in urls {
			let id = "FeatherManualDownload_\(UUID().uuidString)"
			let download = _downloadManager.startArchive(from: url, id: id)
			try? _downloadManager.handlePachageFile(url: url, dl: download)
		}
	}
}
