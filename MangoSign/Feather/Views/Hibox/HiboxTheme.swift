//
//  HiboxTheme.swift
//  艺祥签
//
//  参照嗨签官网的蓝紫青配色，统一 v7 的视觉语言
//

import SwiftUI

enum HiboxTheme {
	static let background = Color(hex: "#F5F7FB")
	static let card = Color.white
	static let text = Color(hex: "#1A2233")
	static let secondaryText = Color(hex: "#8A94A6")
	static let tertiaryText = Color(hex: "#B4BCCB")
	static let separator = Color(hex: "#E8EDF5")
	static let field = Color(hex: "#EEF3FA")

	static let blue = Color(hex: "#3B6CFF")
	static let purple = Color(hex: "#8B5CF6")
	static let cyan = Color(hex: "#3FD0D0")
	static let green = Color(hex: "#21A366")
	static let orange = Color(hex: "#F59E0B")
	static let red = Color(hex: "#EF4444")

	static let gradient = LinearGradient(
		colors: [Color(hex: "#6A8DFF"), Color(hex: "#A77BFF"), Color(hex: "#3FD0D0")],
		startPoint: .topLeading,
		endPoint: .bottomTrailing
	)

	static let softGradient = LinearGradient(
		colors: [
			Color(hex: "#6A8DFF").opacity(0.14),
			Color(hex: "#A77BFF").opacity(0.10),
			Color(hex: "#3FD0D0").opacity(0.12)
		],
		startPoint: .topLeading,
		endPoint: .bottomTrailing
	)

	static let radius: CGFloat = 18
	static let largeRadius: CGFloat = 24
}

extension View {
	func hiboxCard(padding: CGFloat = 14) -> some View {
		self
			.padding(padding)
			.background(HiboxTheme.card, in: RoundedRectangle(cornerRadius: HiboxTheme.radius, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: HiboxTheme.radius, style: .continuous)
					.stroke(Color(hex: "#EDF1F7"), lineWidth: 0.8)
			)
	}
}
