//
//  ServiceCenterView.swift
//  艺祥签
//
//  账号与商城：保留 ABox / 嗨签式的服务入口
//

import SwiftUI
import CoreData
import NimbleViews
import UIKit

struct ServiceCenterView: View {
	@StateObject private var _brand = BrandStore.shared

	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>

	@FetchRequest(
		entity: Signed.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
		animation: .snappy
	) private var _signedApps: FetchedResults<Signed>

	var body: some View {
		NBNavigationView("账号与商城") {
			ScrollView {
				VStack(spacing: 16) {
					_hero()
					_assetCard()
					_noticeCard()
				}
				.padding(.horizontal, 16)
				.padding(.top, 8)
				.padding(.bottom, 30)
			}
			.background(Color(uiColor: .systemGroupedBackground))
			.scrollIndicators(.hidden)
		}
	}

	@ViewBuilder
	private func _hero() -> some View {
		HStack(spacing: 14) {
			Image(systemName: "person.crop.circle.badge.checkmark")
				.font(.system(size: 26, weight: .semibold))
				.foregroundStyle(.white)
				.frame(width: 58, height: 58)
				.background(
					LinearGradient(
						colors: [Color(hex: "#E08A1E"), Color(hex: "#C77B30")],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					),
					in: RoundedRectangle(cornerRadius: 16, style: .continuous)
				)

			VStack(alignment: .leading, spacing: 5) {
				Text("艺祥签服务")
					.font(.title3.weight(.bold))
				Text("本地签名可用，账号体系待接入")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 0)
		}
		.padding(18)
		.background(
			Color(uiColor: .secondarySystemGroupedBackground),
			in: RoundedRectangle(cornerRadius: 24, style: .continuous)
		)
	}

	@ViewBuilder
	private func _assetCard() -> some View {
		VStack(spacing: 0) {
			_serviceRow(title: "账户余额", value: "—", icon: "yensign.circle.fill", color: Color(hex: "#E08A1E"))
			Divider().padding(.leading, 58)
			_serviceRow(title: "签名额度", value: "本机不限次数", icon: "signature", color: _brand.themeColor)
			Divider().padding(.leading, 58)
			_serviceRow(title: "可用证书", value: "\(_certificates.count) 个", icon: "checkmark.seal.fill", color: Color(hex: "#21A366"))
			Divider().padding(.leading, 58)
			_serviceRow(title: "已签名应用", value: "\(_signedApps.count) 个", icon: "square.grid.2x2.fill", color: Color(hex: "#3E7BFA"))
			Divider().padding(.leading, 58)
			_serviceRow(title: "授权记录", value: "—", icon: "list.bullet.rectangle", color: Color(hex: "#8E5CF7"))
		}
		.background(
			Color(uiColor: .secondarySystemGroupedBackground),
			in: RoundedRectangle(cornerRadius: 20, style: .continuous)
		)
	}

	private func _serviceRow(title: String, value: String, icon: String, color: Color) -> some View {
		HStack(spacing: 12) {
			Image(systemName: icon)
				.font(.system(size: 16, weight: .semibold))
				.foregroundStyle(color)
				.frame(width: 34, height: 34)
				.background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

			Text(title)
				.font(.subheadline.weight(.medium))

			Spacer(minLength: 0)

			Text(value)
				.font(.subheadline)
				.foregroundStyle(.secondary)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 13)
	}

	@ViewBuilder
	private func _noticeCard() -> some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 8) {
				Image(systemName: "info.circle.fill")
					.font(.caption.weight(.bold))
					.foregroundStyle(Color(hex: "#E08A1E"))
				Text("关于账号与商城")
					.font(.subheadline.weight(.semibold))
			}

			Text("当前版本是本地签名版：导入 IPA、选择证书、签名和安装都可以直接使用，不需要登录账号。\n\n余额充值、购买证书、卡密兑换、授权记录属于服务端功能，需要接入账号与订单接口后才会开放。")
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
		.background(
			Color(uiColor: .secondarySystemGroupedBackground),
			in: RoundedRectangle(cornerRadius: 20, style: .continuous)
		)
	}
}
