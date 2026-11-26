//
//  FilesView.swift
//  艺祥签
//
//  ABox 架构的第三页：文件。应用目录 + 文档，可导入、预览、删除。
//

import SwiftUI
import NimbleViews
import QuickLook
import UniformTypeIdentifiers

struct FilesView: View {
	@State private var _rootItems: [HiboxFileItem] = []
	@State private var _storageText = ""
	@State private var _isImportingPresenting = false
	@State private var _isNewFolderPresenting = false
	@State private var _newFolderName = ""
	@State private var _previewURL: URL?
	@State private var _errorMessage: String?

	private let _root = URL.documentsDirectory

	private var _appDirectories: [HiboxFileItem] {
		_rootItems.filter {
			$0.isDirectory && ["Unsigned", "Signed", "Archives", "Certificates"].contains($0.name)
		}
	}

	private var _documentItems: [HiboxFileItem] {
		_rootItems.filter {
			!($0.isDirectory && ["Unsigned", "Signed", "Archives", "Certificates"].contains($0.name))
		}
	}

	var body: some View {
		NBNavigationView("") {
			ScrollView {
				VStack(spacing: 14) {
					_header()
					_storageCard()
					_appDirectorySection()
					_documentSection()
				}
				.padding(.horizontal, 16)
				.padding(.top, 6)
				.padding(.bottom, 30)
			}
			.background(HiboxTheme.background)
			.scrollIndicators(.hidden)
			.toolbar(.hidden, for: .navigationBar)
			.onAppear { _reload() }
			.sheet(isPresented: $_isImportingPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.item],
					allowsMultipleSelection: true,
					onDocumentsPicked: { urls in
						_importFiles(urls, to: _root)
					}
				)
				.ignoresSafeArea()
			}
			.alert("新建文件夹", isPresented: $_isNewFolderPresenting) {
				TextField("文件夹名称", text: $_newFolderName)
				Button("取消", role: .cancel) { _newFolderName = "" }
				Button("创建") {
					_createFolder(named: _newFolderName, in: _root)
					_newFolderName = ""
				}
			}
			.alert("操作失败", isPresented: Binding(
				get: { _errorMessage != nil },
				set: { if !$0 { _errorMessage = nil } }
			)) {
				Button("好", role: .cancel) { _errorMessage = nil }
			} message: {
				Text(_errorMessage ?? "")
			}
			.sheet(item: Binding(
				get: { _previewURL.map(PreviewItem.init) },
				set: { _previewURL = $0?.url }
			)) { item in
				FilePreviewView(url: item.url)
					.ignoresSafeArea()
			}
		}
	}
}

// MARK: - Sections
extension FilesView {
	@ViewBuilder
	private func _header() -> some View {
		HStack(alignment: .center, spacing: 12) {
			ZStack {
				Circle()
					.fill(.white.opacity(0.20))
					.frame(width: 48, height: 48)
				Image(systemName: "folder.fill")
					.font(.system(size: 22, weight: .semibold))
					.foregroundStyle(.white)
			}

			VStack(alignment: .leading, spacing: 3) {
				Text("文件")
					.font(.system(size: 19, weight: .bold))
					.foregroundStyle(.white)
				Text("签名文件与本地文档")
					.font(.caption)
					.foregroundStyle(.white.opacity(0.82))
			}

			Spacer(minLength: 0)

			Menu {
				Button("导入文件", systemImage: "square.and.arrow.down") {
					_isImportingPresenting = true
				}
				Button("新建文件夹", systemImage: "folder.badge.plus") {
					_isNewFolderPresenting = true
				}
			} label: {
				Image(systemName: "plus")
					.font(.system(size: 16, weight: .bold))
					.foregroundStyle(.white)
					.frame(width: 34, height: 34)
					.background(.white.opacity(0.18), in: Circle())
			}
		}
		.padding(18)
		.background(
			ZStack(alignment: .topTrailing) {
				HiboxTheme.gradient
				Circle()
					.fill(.white.opacity(0.12))
					.frame(width: 150, height: 150)
					.offset(x: 55, y: -75)
			}
		)
		.clipShape(RoundedRectangle(cornerRadius: HiboxTheme.largeRadius, style: .continuous))
		.shadow(color: HiboxTheme.cyan.opacity(0.18), radius: 16, x: 0, y: 8)
	}

	@ViewBuilder
	private func _storageCard() -> some View {
		HStack(spacing: 12) {
			Image(systemName: "internaldrive.fill")
				.font(.system(size: 18, weight: .semibold))
				.foregroundStyle(HiboxTheme.blue)
				.frame(width: 36, height: 36)
				.background(HiboxTheme.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

			VStack(alignment: .leading, spacing: 3) {
				Text("本地文件")
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(HiboxTheme.text)
				Text(_storageText.isEmpty ? "正在计算…" : _storageText)
					.font(.caption2)
					.foregroundStyle(HiboxTheme.secondaryText)
			}

			Spacer(minLength: 0)
		}
		.hiboxCard(padding: 12)
	}

	@ViewBuilder
	private func _appDirectorySection() -> some View {
		VStack(spacing: 10) {
			HiboxSectionHeader(title: "应用目录", subtitle: "签名工作区")

			LazyVGrid(
				columns: [
					GridItem(.flexible(), spacing: 10),
					GridItem(.flexible(), spacing: 10)
				],
				spacing: 10
			) {
				ForEach(_appDirectories) { item in
					NavigationLink {
						FileBrowserView(url: item.url, title: _friendlyName(item.name))
					} label: {
						_directoryCard(item)
					}
					.buttonStyle(.plain)
				}

				if _appDirectories.isEmpty {
					ForEach(HiboxFileItem.defaultDirectories, id: \.url) { item in
						NavigationLink {
							FileBrowserView(url: item.url, title: _friendlyName(item.name))
						} label: {
							_directoryCard(item)
						}
						.buttonStyle(.plain)
					}
				}
			}
		}
	}

	@ViewBuilder
	private func _directoryCard(_ item: HiboxFileItem) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack {
				Image(systemName: _folderIcon(item.name))
					.font(.system(size: 20, weight: .semibold))
					.foregroundStyle(_folderColor(item.name))
					.frame(width: 38, height: 38)
					.background(_folderColor(item.name).opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
				Spacer(minLength: 0)
				Image(systemName: "chevron.right")
					.font(.system(size: 11, weight: .bold))
					.foregroundStyle(HiboxTheme.tertiaryText)
			}

			Text(_friendlyName(item.name))
				.font(.system(size: 14, weight: .semibold))
				.foregroundStyle(HiboxTheme.text)
				.lineLimit(1)

			Text("\(item.childCount) 项")
				.font(.caption2)
				.foregroundStyle(HiboxTheme.secondaryText)
		}
		.hiboxCard(padding: 13)
	}

	@ViewBuilder
	private func _documentSection() -> some View {
		VStack(spacing: 10) {
			HiboxSectionHeader(
				title: "文档",
				subtitle: _documentItems.isEmpty ? nil : "\(_documentItems.count) 项"
			)

			if _documentItems.isEmpty {
				VStack(spacing: 10) {
					Image(systemName: "doc.badge.plus")
						.font(.system(size: 24, weight: .medium))
						.foregroundStyle(HiboxTheme.blue)
					Text("暂无文档")
						.font(.footnote)
						.foregroundStyle(HiboxTheme.secondaryText)
					Button {
						_isImportingPresenting = true
					} label: {
						HiboxGradientPill(title: "导入文件", icon: "square.and.arrow.down")
					}
					.buttonStyle(.plain)
				}
				.frame(maxWidth: .infinity)
				.padding(.vertical, 26)
				.hiboxCard(padding: 14)
			} else {
				VStack(spacing: 0) {
					ForEach(Array(_documentItems.enumerated()), id: \.element.id) { index, item in
						if item.isDirectory {
							NavigationLink {
								FileBrowserView(url: item.url, title: item.name)
							} label: {
								HiboxFileRow(item: item)
							}
							.buttonStyle(.plain)
						} else {
							Button {
								_previewURL = item.url
							} label: {
								HiboxFileRow(item: item)
							}
							.buttonStyle(.plain)
							.contextMenu {
								ShareLink(item: item.url)
								Button("删除", systemImage: "trash", role: .destructive) {
									_delete(item)
								}
							}
						}

						if index < _documentItems.count - 1 {
							Divider()
								.overlay(HiboxTheme.separator)
								.padding(.leading, 58)
						}
					}
				}
				.hiboxCard(padding: 6)
			}
		}
	}
}

// MARK: - Helpers
extension FilesView {
	private func _friendlyName(_ name: String) -> String {
		switch name {
		case "Unsigned":		return "待签名应用"
		case "Signed":			return "已签名应用"
		case "Archives":		return "归档"
		case "Certificates":	return "证书"
		default:				return name
		}
	}

	private func _folderIcon(_ name: String) -> String {
		switch name {
		case "Unsigned":		return "shippingbox.fill"
		case "Signed":			return "checkmark.seal.fill"
		case "Archives":		return "archivebox.fill"
		case "Certificates":	return "key.fill"
		default:				return "folder.fill"
		}
	}

	private func _folderColor(_ name: String) -> Color {
		switch name {
		case "Unsigned":		return HiboxTheme.blue
		case "Signed":			return HiboxTheme.green
		case "Archives":		return HiboxTheme.orange
		case "Certificates":	return HiboxTheme.purple
		default:				return HiboxTheme.blue
		}
	}

	private func _reload() {
		_rootItems = HiboxFileItem.items(in: _root)
		_storageText = HiboxFileItem.storageDescription(for: _root)
	}

	private func _importFiles(_ urls: [URL], to directory: URL) {
		do {
			try HiboxFileItem.importFiles(urls, to: directory)
			_reload()
		} catch {
			_errorMessage = error.localizedDescription
		}
	}

	private func _createFolder(named name: String, in directory: URL) {
		let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		do {
			try FileManager.default.createDirectory(
				at: directory.appendingPathComponent(trimmed),
				withIntermediateDirectories: true
			)
			_reload()
		} catch {
			_errorMessage = error.localizedDescription
		}
	}

	private func _delete(_ item: HiboxFileItem) {
		do {
			try FileManager.default.removeItem(at: item.url)
			_reload()
		} catch {
			_errorMessage = error.localizedDescription
		}
	}
}

// MARK: - Browser
struct FileBrowserView: View {
	let url: URL
	let title: String

	@State private var _items: [HiboxFileItem] = []
	@State private var _isImportingPresenting = false
	@State private var _isNewFolderPresenting = false
	@State private var _newFolderName = ""
	@State private var _previewURL: URL?
	@State private var _errorMessage: String?

	var body: some View {
		ScrollView {
			VStack(spacing: 12) {
				HStack {
					Text(url.path.replacingOccurrences(of: URL.documentsDirectory.path, with: "文件"))
						.font(.caption2)
						.foregroundStyle(HiboxTheme.secondaryText)
						.lineLimit(1)
					Spacer(minLength: 0)
					Text("\(_items.count) 项")
						.font(.caption2)
						.foregroundStyle(HiboxTheme.tertiaryText)
				}
				.padding(.horizontal, 4)

				if _items.isEmpty {
					HiboxEmptyState(
						icon: "folder",
						title: "空文件夹",
						message: "这里还没有文件，可以从右上角导入。",
						actionTitle: "导入文件",
						action: { _isImportingPresenting = true }
					)
				} else {
					VStack(spacing: 0) {
						ForEach(Array(_items.enumerated()), id: \.element.id) { index, item in
							if item.isDirectory {
								NavigationLink {
									FileBrowserView(url: item.url, title: item.name)
								} label: {
									HiboxFileRow(item: item)
								}
								.buttonStyle(.plain)
							} else {
								Button {
									_previewURL = item.url
								} label: {
									HiboxFileRow(item: item)
								}
								.buttonStyle(.plain)
								.contextMenu {
									ShareLink(item: item.url)
									Button("删除", systemImage: "trash", role: .destructive) {
										_delete(item)
									}
								}
							}

							if index < _items.count - 1 {
								Divider()
									.overlay(HiboxTheme.separator)
									.padding(.leading, 58)
							}
						}
					}
					.hiboxCard(padding: 6)
				}
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 12)
		}
		.background(HiboxTheme.background)
		.scrollIndicators(.hidden)
		.navigationTitle(title)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar(.visible, for: .navigationBar)
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Menu {
					Button("导入文件", systemImage: "square.and.arrow.down") {
						_isImportingPresenting = true
					}
					Button("新建文件夹", systemImage: "folder.badge.plus") {
						_isNewFolderPresenting = true
					}
				} label: {
					Image(systemName: "plus")
				}
			}
		}
		.onAppear { _reload() }
		.sheet(isPresented: $_isImportingPresenting) {
			FileImporterRepresentableView(
				allowedContentTypes: [.item],
				allowsMultipleSelection: true,
				onDocumentsPicked: { urls in
					_importFiles(urls)
				}
			)
			.ignoresSafeArea()
		}
		.alert("新建文件夹", isPresented: $_isNewFolderPresenting) {
			TextField("文件夹名称", text: $_newFolderName)
			Button("取消", role: .cancel) { _newFolderName = "" }
			Button("创建") {
				_createFolder(named: _newFolderName)
				_newFolderName = ""
			}
		}
		.alert("操作失败", isPresented: Binding(
			get: { _errorMessage != nil },
			set: { if !$0 { _errorMessage = nil } }
		)) {
			Button("好", role: .cancel) { _errorMessage = nil }
		} message: {
			Text(_errorMessage ?? "")
		}
		.sheet(item: Binding(
			get: { _previewURL.map(PreviewItem.init) },
			set: { _previewURL = $0?.url }
		)) { item in
			FilePreviewView(url: item.url)
				.ignoresSafeArea()
		}
	}
}

extension FileBrowserView {
	private func _reload() {
		_items = HiboxFileItem.items(in: url)
	}

	private func _importFiles(_ urls: [URL]) {
		do {
			try HiboxFileItem.importFiles(urls, to: url)
			_reload()
		} catch {
			_errorMessage = error.localizedDescription
		}
	}

	private func _createFolder(named name: String) {
		let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		do {
			try FileManager.default.createDirectory(
				at: url.appendingPathComponent(trimmed),
				withIntermediateDirectories: true
			)
			_reload()
		} catch {
			_errorMessage = error.localizedDescription
		}
	}

	private func _delete(_ item: HiboxFileItem) {
		do {
			try FileManager.default.removeItem(at: item.url)
			_reload()
		} catch {
			_errorMessage = error.localizedDescription
		}
	}
}

// MARK: - Row
struct HiboxFileRow: View {
	let item: HiboxFileItem

	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: item.icon)
				.font(.system(size: 18, weight: .semibold))
				.foregroundStyle(item.iconColor)
				.frame(width: 40, height: 40)
				.background(item.iconColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

			VStack(alignment: .leading, spacing: 3) {
				Text(item.name)
					.font(.system(size: 14, weight: .medium))
					.foregroundStyle(HiboxTheme.text)
					.lineLimit(1)

				Text(item.detailText)
					.font(.caption2)
					.foregroundStyle(HiboxTheme.secondaryText)
			}

			Spacer(minLength: 0)

			if item.isDirectory {
				Image(systemName: "chevron.right")
					.font(.system(size: 11, weight: .bold))
					.foregroundStyle(HiboxTheme.tertiaryText)
			}
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 10)
		.contentShape(Rectangle())
	}
}

// MARK: - Model & File Helpers
struct HiboxFileItem: Identifiable {
	let url: URL
	let name: String
	let isDirectory: Bool
	let size: Int64
	let modified: Date?
	let childCount: Int

	var id: String { url.path }

	var icon: String {
		if isDirectory { return "folder.fill" }
		switch url.pathExtension.lowercased() {
		case "ipa", "tipa":			return "shippingbox.fill"
		case "p12", "cer":			return "key.fill"
		case "mobileprovision":		return "doc.badge.gearshape"
		case "zip", "7z", "rar":		return "archivebox.fill"
		case "dylib", "deb":			return "puzzlepiece.extension.fill"
		case "png", "jpg", "jpeg", "heic", "gif":	return "photo.fill"
		case "mp4", "mov":			return "play.rectangle.fill"
		case "mp3", "m4a", "wav":		return "waveform"
		case "plist":				return "list.bullet.rectangle"
		default:					return "doc.fill"
		}
	}

	var iconColor: Color {
		if isDirectory { return HiboxTheme.orange }
		switch url.pathExtension.lowercased() {
		case "ipa", "tipa":			return HiboxTheme.blue
		case "p12", "cer":			return HiboxTheme.purple
		case "mobileprovision":		return HiboxTheme.orange
		case "zip", "7z", "rar":		return HiboxTheme.cyan
		case "dylib", "deb":			return HiboxTheme.green
		case "png", "jpg", "jpeg", "heic", "gif":	return HiboxTheme.purple
		case "mp4", "mov":			return HiboxTheme.blue
		default:					return HiboxTheme.secondaryText
		}
	}

	var detailText: String {
		var parts: [String] = []
		if isDirectory {
			parts.append("\(childCount) 项")
		} else {
			parts.append(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
		}
		if let modified {
			parts.append(modified.formatted(date: .numeric, time: .shortened))
		}
		return parts.joined(separator: " · ")
	}

	static var defaultDirectories: [HiboxFileItem] {
		[
			HiboxFileItem(url: FileManager.default.unsigned, name: "Unsigned", isDirectory: true, size: 0, modified: nil, childCount: 0),
			HiboxFileItem(url: FileManager.default.signed, name: "Signed", isDirectory: true, size: 0, modified: nil, childCount: 0),
			HiboxFileItem(url: FileManager.default.archives, name: "Archives", isDirectory: true, size: 0, modified: nil, childCount: 0),
			HiboxFileItem(url: FileManager.default.certificates, name: "Certificates", isDirectory: true, size: 0, modified: nil, childCount: 0)
		]
	}

	static func items(in directory: URL) -> [HiboxFileItem] {
		let keys: [URLResourceKey] = [
			.isDirectoryKey,
			.fileSizeKey,
			.totalFileAllocatedSizeKey,
			.contentModificationDateKey
		]

		guard let urls = try? FileManager.default.contentsOfDirectory(
			at: directory,
			includingPropertiesForKeys: keys,
			options: [.skipsHiddenFiles]
		) else {
			return []
		}

		let items = urls.compactMap { url -> HiboxFileItem? in
			let values = try? url.resourceValues(forKeys: Set(keys))
			let isDirectory = values?.isDirectory ?? false
			let size = Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
			let count = isDirectory
				? (try? FileManager.default.contentsOfDirectory(atPath: url.path).count) ?? 0
				: 0

			return HiboxFileItem(
				url: url,
				name: url.lastPathComponent,
				isDirectory: isDirectory,
				size: size,
				modified: values?.contentModificationDate,
				childCount: count
			)
		}

		return items.sorted {
			if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
			return $0.name.localizedStandardCompare($1.name) == .orderedAscending
		}
	}

	static func importFiles(_ urls: [URL], to directory: URL) throws {
		for url in urls {
			let scoped = url.startAccessingSecurityScopedResource()
			defer { if scoped { url.stopAccessingSecurityScopedResource() } }

			let destination = uniqueDestination(for: url.lastPathComponent, in: directory)
			try FileManager.default.copyItem(at: url, to: destination)
		}
	}

	private static func uniqueDestination(for name: String, in directory: URL) -> URL {
		let target = directory.appendingPathComponent(name)
		guard FileManager.default.fileExists(atPath: target.path) else { return target }

		let base = (name as NSString).deletingPathExtension
		let ext = (name as NSString).pathExtension
		var index = 2
		while true {
			let candidateName = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
			let candidate = directory.appendingPathComponent(candidateName)
			if !FileManager.default.fileExists(atPath: candidate.path) {
				return candidate
			}
			index += 1
		}
	}

	static func storageDescription(for directory: URL) -> String {
		let used = _directorySize(directory)
		let values = try? directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
		let available = Int64(values?.volumeAvailableCapacityForImportantUsage ?? 0)

		let usedText = ByteCountFormatter.string(fromByteCount: used, countStyle: .file)
		let availableText = ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
		return "艺祥签占用 \(usedText) · 设备可用 \(availableText)"
	}

	private static func _directorySize(_ directory: URL) -> Int64 {
		var total: Int64 = 0
		let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]

		if let enumerator = FileManager.default.enumerator(
			at: directory,
			includingPropertiesForKeys: keys,
			options: [.skipsHiddenFiles]
		) {
			for case let url as URL in enumerator {
				let values = try? url.resourceValues(forKeys: Set(keys))
				if values?.isRegularFile == true {
					total += Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
				}
			}
		}
		return total
	}
}

// MARK: - Preview
struct PreviewItem: Identifiable {
	let url: URL
	var id: String { url.path }
}

struct FilePreviewView: UIViewControllerRepresentable {
	let url: URL

	func makeUIViewController(context: Context) -> QLPreviewController {
		let controller = QLPreviewController()
		controller.dataSource = context.coordinator
		return controller
	}

	func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

	func makeCoordinator() -> Coordinator {
		Coordinator(url: url)
	}

	final class Coordinator: NSObject, QLPreviewControllerDataSource {
		let url: URL

		init(url: URL) {
			self.url = url
		}

		func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
			1
		}

		func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
			url as NSURL
		}
	}
}
