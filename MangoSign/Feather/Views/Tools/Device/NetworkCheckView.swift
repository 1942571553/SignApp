//
//  NetworkCheckView.swift
//  艺祥签
//
//  网络检测：检查签名服务与品牌接口连通性
//

import SwiftUI
import NimbleViews

struct NetworkCheckView: View {
	private struct CheckResult: Identifiable {
		let id = UUID()
		let title: String
		let detail: String
		let ok: Bool
		let latency: Int?
	}

	@StateObject private var _brand = BrandStore.shared
	@State private var _isChecking = false
	@State private var _results: [CheckResult] = []
	@State private var _lastCheck: Date?

	var body: some View {
		NBNavigationView("网络检测") {
			ScrollView {
				VStack(spacing: 16) {
					_summary()
					_button()

					if !_results.isEmpty {
						VStack(spacing: 0) {
							ForEach(Array(_results.enumerated()), id: \.element.id) { index, result in
								_resultRow(result)
								if index < _results.count - 1 {
									Divider().padding(.leading, 58)
								}
							}
						}
						.background(
							Color(uiColor: .secondarySystemGroupedBackground),
							in: RoundedRectangle(cornerRadius: 20, style: .continuous)
						)
					}

					Text("检测只发起普通的 HTTPS 请求，不会上传设备信息。")
						.font(.caption2)
						.foregroundStyle(.secondary)
						.padding(.horizontal, 4)
				}
				.padding(.horizontal, 16)
				.padding(.top, 8)
				.padding(.bottom, 28)
			}
			.background(Color(uiColor: .systemGroupedBackground))
			.scrollIndicators(.hidden)
		}
	}

	@ViewBuilder
	private func _summary() -> some View {
		HStack(spacing: 14) {
			ZStack {
				Circle()
					.fill(Color(hex: "#8E5CF7").opacity(0.12))
					.frame(width: 56, height: 56)
				Image(systemName: "wifi")
					.font(.system(size: 24, weight: .semibold))
					.foregroundStyle(Color(hex: "#8E5CF7"))
			}

			VStack(alignment: .leading, spacing: 4) {
				Text("签名服务连通性")
					.font(.headline)
				Text(_lastCheck == nil ? "点击下方按钮开始检测" : "上次检测：\(_lastCheck!.formatted(date: .abbreviated, time: .shortened))")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 0)
		}
		.padding(16)
		.background(
			Color(uiColor: .secondarySystemGroupedBackground),
			in: RoundedRectangle(cornerRadius: 20, style: .continuous)
		)
	}

	@ViewBuilder
	private func _button() -> some View {
		Button {
			Task { await _runChecks() }
		} label: {
			HStack(spacing: 8) {
				if _isChecking {
					ProgressView().tint(.white)
				} else {
					Image(systemName: "antenna.radiowaves.left.and.right")
				}
				Text(_isChecking ? "正在检测…" : "开始检测")
					.font(.subheadline.weight(.semibold))
			}
			.foregroundStyle(.white)
			.frame(maxWidth: .infinity)
			.padding(.vertical, 14)
			.background(_brand.themeColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
		}
		.buttonStyle(.plain)
		.disabled(_isChecking)
	}

	@ViewBuilder
	private func _resultRow(_ result: CheckResult) -> some View {
		HStack(spacing: 12) {
			Image(systemName: result.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
				.font(.system(size: 20, weight: .semibold))
				.foregroundStyle(result.ok ? Color(hex: "#21A366") : Color(hex: "#D9534F"))

			VStack(alignment: .leading, spacing: 3) {
				Text(result.title)
					.font(.subheadline.weight(.medium))
				Text(result.detail)
					.font(.caption2)
					.foregroundStyle(.secondary)
					.lineLimit(2)
			}

			Spacer(minLength: 0)

			if let latency = result.latency {
				Text("\(latency) ms")
					.font(.caption2.weight(.semibold))
					.foregroundStyle(.secondary)
			}
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 12)
	}

	private func _runChecks() async {
		_isChecking = true
		defer { _isChecking = false }

		var results: [CheckResult] = []

		if let configURL = URL(string: _brand.configURL) {
			results.append(await _check(title: "品牌配置接口", url: configURL, host: configURL.host ?? "—"))
		}

		if let siteURL = URL(string: "https://sign.yixsc.cn") {
			results.append(await _check(title: "签名站点", url: siteURL, host: siteURL.host ?? "—"))
		}

		results.append(
			CheckResult(
				title: "本机网络环境",
				detail: "已发起 HTTPS 请求，若上方失败请检查 Wi-Fi / 蜂窝网络或代理设置。",
				ok: results.contains { $0.ok },
				latency: nil
			)
		)

		_results = results
		_lastCheck = Date()
	}

	private func _check(title: String, url: URL, host: String) async -> CheckResult {
		var request = URLRequest(url: url)
		request.timeoutInterval = 12
		request.httpMethod = "GET"
		request.cachePolicy = .reloadIgnoringLocalCacheData

		let start = Date()

		do {
			let (_, response) = try await URLSession.shared.data(for: request)
			let elapsed = Int(Date().timeIntervalSince(start) * 1000)
			let code = (response as? HTTPURLResponse)?.statusCode ?? -1
			let ok = (200..<300).contains(code)
			return CheckResult(
				title: title,
				detail: "\(host) · HTTP \(code)",
				ok: ok,
				latency: elapsed
			)
		} catch {
			let elapsed = Int(Date().timeIntervalSince(start) * 1000)
			return CheckResult(
				title: title,
				detail: "\(host) · \(error.localizedDescription)",
				ok: false,
				latency: elapsed
			)
		}
	}
}
