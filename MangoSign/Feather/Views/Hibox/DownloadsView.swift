//
//  DownloadsView.swift
//  艺祥签
//
//  ABox 架构的第四页：下载。URL 下载队列与解包进度。
//

import SwiftUI
import NimbleViews

struct DownloadsView: View {
	@StateObject private var _manager = DownloadManager.shared

	@State private var _isURLPresenting = false
	@State private var _urlString = ""

	var body: some View {
		NBNavigationView("") {
			ScrollView {
				VStack(spacing: 14) {
					_header()
					_content()
				}
				.padding(.horizontal, 16)
				.padding(.top, 6)
				.padding(.bottom, 30)
			}
			.background(HiboxTheme.background)
			.scrollIndicators(.hidden)
			.toolbar(.hidden, for: .navigationBar)
			.alert("新建下载", isPresented: $_isURLPresenting) {
				TextField("https://example.com/app.ipa", text: $_urlString)
					.textInputAutocapitalization(.never)
					.keyboardType(.URL)
				Button("取消", role: .cancel) { _urlString = "" }
				Button("下载") {
					if let url = URL(string: _urlString) {
						_ = _manager.startDownload(
							from: url,
							id: "FeatherManualDownload_\(UUID().uuidString)"
						)
					}
					_urlString = ""
				}
			} message: {
				Text("支持 IPA 直链，下载完成后会自动导入到待签名列表。")
			}
		}
	}
}

// MARK: - Sections
extension DownloadsView {
	@ViewBuilder
	private func _header() -> some View {
		HStack(alignment: .center, spacing: 12) {
			ZStack {
				Circle()
					.fill(.white.opacity(0.20))
					.frame(width: 48, height: 48)
				Image(systemName: "arrow.down.circle.fill")
					.font(.system(size: 23, weight: .semibold))
					.foregroundStyle(.white)
			}

			VStack(alignment: .leading, spacing: 3) {
				Text("下载")
					.font(.system(size: 19, weight: .bold))
					.foregroundStyle(.white)
				Text(_manager.downloads.isEmpty ? "当前没有下载任务" : "\(_manager.downloads.count) 个任务进行中")
					.font(.caption)
					.foregroundStyle(.white.opacity(0.82))
			}

			Spacer(minLength: 0)

			Button {
				_isURLPresenting = true
			} label: {
				Image(systemName: "plus")
					.font(.system(size: 16, weight: .bold))
					.foregroundStyle(.white)
					.frame(width: 34, height: 34)
					.background(.white.opacity(0.18), in: Circle())
			}
			.buttonStyle(.plain)
		}
		.padding(18)
		.background(
			ZStack(alignment: .topTrailing) {
				HiboxTheme.gradient
				Circle()
					.fill(.white.opacity(0.12))
					.frame(width: 160, height: 160)
					.offset(x: 55, y: -80)
			}
		)
		.clipShape(RoundedRectangle(cornerRadius: HiboxTheme.largeRadius, style: .continuous))
		.shadow(color: HiboxTheme.blue.opacity(0.18), radius: 16, x: 0, y: 8)
	}

	@ViewBuilder
	private func _content() -> some View {
		if _manager.downloads.isEmpty {
			HiboxEmptyState(
				icon: "tray.and.arrow.down.fill",
				title: "暂无数据",
				message: "通过链接下载 IPA，或从「应用」页下载软件源里的应用。",
				actionTitle: "新建下载",
				action: { _isURLPresenting = true }
			)
			.padding(.top, 20)
		} else {
			VStack(spacing: 10) {
				HiboxSectionHeader(
					title: "下载任务",
					subtitle: "\(_manager.downloads.count) 个",
					trailing: "左滑或长按可取消"
				)

				LazyVStack(spacing: 10) {
					ForEach(_manager.downloads) { download in
						DownloadRow(download: download) {
							_manager.cancelDownload(download)
						}
					}
				}
			}
		}
	}
}

// MARK: - Row
struct DownloadRow: View {
	let download: Download

	var onCancel: () -> Void

	var body: some View {
		TimelineView(.periodic(from: .now, by: 0.45)) { _ in
			_content
		}
	}

	private var _content: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 12) {
				Image(systemName: download.onlyArchiving ? "archivebox.fill" : "arrow.down.doc.fill")
					.font(.system(size: 19, weight: .semibold))
					.foregroundStyle(HiboxTheme.blue)
					.frame(width: 42, height: 42)
					.background(HiboxTheme.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

				VStack(alignment: .leading, spacing: 3) {
					Text(download.fileName)
						.font(.system(size: 14, weight: .semibold))
						.foregroundStyle(HiboxTheme.text)
						.lineLimit(1)

					Text(_statusText)
						.font(.caption2)
						.foregroundStyle(HiboxTheme.secondaryText)
						.lineLimit(1)
				}

				Spacer(minLength: 0)

				Button(action: onCancel) {
					Image(systemName: "xmark")
						.font(.system(size: 12, weight: .bold))
						.foregroundStyle(HiboxTheme.secondaryText)
						.frame(width: 28, height: 28)
						.background(HiboxTheme.field, in: Circle())
				}
				.buttonStyle(.plain)
			}

			GeometryReader { proxy in
				ZStack(alignment: .leading) {
					Capsule()
						.fill(HiboxTheme.field)
					Capsule()
						.fill(HiboxTheme.gradient)
						.frame(width: max(6, proxy.size.width * _progress))
				}
			}
			.frame(height: 6)

			HStack {
				Text("\(Int(_progress * 100))%")
					.font(.caption2.weight(.semibold))
					.foregroundStyle(HiboxTheme.blue)
				Spacer(minLength: 0)
				Text(_bytesText)
					.font(.caption2)
					.foregroundStyle(HiboxTheme.secondaryText)
			}
		}
		.hiboxCard(padding: 13)
	}

	private var _progress: Double {
		min(max(download.overallProgress, 0), 1)
	}

	private var _statusText: String {
		if download.onlyArchiving || download.progress >= 1 {
			return "正在解包并导入…"
		}
		return download.totalBytes > 0 ? "正在下载" : "等待响应"
	}

	private var _bytesText: String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		let downloaded = formatter.string(fromByteCount: download.bytesDownloaded)
		if download.totalBytes > 0 {
			return "\(downloaded) / \(formatter.string(fromByteCount: download.totalBytes))"
		}
		return downloaded
	}
}
