//
//  BrandConfig.swift
//  芒果签名
//
//  从品牌服务拉取远程配置：名称、公告、主题色、客服链接、功能开关。
//

import Foundation
import SwiftUI

struct BrandInfo: Codable, Equatable {
	var app_name: String?
	var app_title: String?
	var subtitle: String?
	var theme_color: String?
	var announcement: String?
	var support_url: String?
	var logo_url: String?
}

struct ClientInfo: Codable, Equatable {
	var version: String?
	var download_url: String?
	var min_version: String?
	var force_update: Bool?
	var allow_sign: Bool?
	var allow_install: Bool?
}

struct BrandConfigResponse: Codable, Equatable {
	var ok: Bool?
	var brand: BrandInfo?
	var client: ClientInfo?
}

@MainActor
final class BrandStore: ObservableObject {
	static let shared = BrandStore()

	/// 后台「品牌」页填的站点地址 + 配置 token，可在 App 设置里改
	static let defaultConfigURL = "https://your-domain.com/api/config?token=REPLACE_WITH_YOUR_TOKEN"

	@Published var brand: BrandInfo?
	@Published var client: ClientInfo?
	@Published var lastError: String?
	@Published var lastSync: Date?

	private let _urlKey = "mango.config.url"
	private let _cacheKey = "mango.config.cache"

	var configURL: String {
		get { UserDefaults.standard.string(forKey: _urlKey) ?? Self.defaultConfigURL }
		set { UserDefaults.standard.set(newValue, forKey: _urlKey) }
	}

	init() {
		_loadCache()
	}

	var displayName: String {
		if let name = brand?.app_name, !name.isEmpty {
			return name
		}
		return Bundle.main.name
	}

	var announcement: String? {
		guard let text = brand?.announcement, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			return nil
		}
		return text
	}

	var supportURL: URL? {
		guard let string = brand?.support_url, let url = URL(string: string), !string.isEmpty else {
			return nil
		}
		return url
	}

	var themeColor: Color {
		guard let hex = brand?.theme_color, !hex.isEmpty else { return Color.accentColor }
		return Color(hex: hex)
	}

	func refresh() async {
		let raw = configURL.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !raw.isEmpty, let url = URL(string: raw), url.scheme != nil else {
			lastError = "配置地址为空或不合法"
			return
		}

		do {
			var request = URLRequest(url: url)
			request.timeoutInterval = 15
			request.cachePolicy = .reloadIgnoringLocalCacheData

			let (data, response) = try await URLSession.shared.data(for: request)
			guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
				throw BrandError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
			}

			let decoded = try JSONDecoder().decode(BrandConfigResponse.self, from: data)
			guard decoded.ok != false else { throw BrandError.notOK }

			brand = decoded.brand
			client = decoded.client
			lastError = nil
			lastSync = Date()
			_saveCache(decoded)
		} catch {
			lastError = error.localizedDescription
			_loadCache()
		}
	}

	private func _saveCache(_ value: BrandConfigResponse) {
		if let data = try? JSONEncoder().encode(value) {
			UserDefaults.standard.set(data, forKey: _cacheKey)
		}
	}

	private func _loadCache() {
		guard
			let data = UserDefaults.standard.data(forKey: _cacheKey),
			let cached = try? JSONDecoder().decode(BrandConfigResponse.self, from: data)
		else {
			return
		}
		brand = cached.brand
		client = cached.client
	}
}

enum BrandError: LocalizedError {
	case badStatus(Int)
	case notOK

	var errorDescription: String? {
		switch self {
		case .badStatus(let code): return "服务器返回 HTTP \(code)"
		case .notOK: return "配置接口返回 ok=false"
		}
	}
}
