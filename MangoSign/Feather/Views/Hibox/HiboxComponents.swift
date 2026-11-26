//
//  HiboxComponents.swift
//  艺祥签
//

import SwiftUI
import NukeUI

struct HiboxSectionHeader: View {
	let title: String
	var subtitle: String?
	var trailing: String?

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: 8) {
			Text(title)
				.font(.system(size: 20, weight: .bold))
				.foregroundStyle(HiboxTheme.text)

			if let subtitle {
				Text(subtitle)
					.font(.caption)
					.foregroundStyle(HiboxTheme.secondaryText)
			}

			Spacer(minLength: 0)

			if let trailing {
				Text(trailing)
					.font(.caption.weight(.medium))
					.foregroundStyle(HiboxTheme.secondaryText)
			}
		}
		.padding(.horizontal, 2)
	}
}

struct HiboxGradientPill: View {
	let title: String
	var icon: String?

	var body: some View {
		HStack(spacing: 4) {
			if let icon {
				Image(systemName: icon)
					.font(.system(size: 11, weight: .semibold))
			}
			Text(title)
				.font(.caption.weight(.semibold))
		}
		.foregroundStyle(.white)
		.padding(.horizontal, 12)
		.padding(.vertical, 7)
		.background(HiboxTheme.gradient, in: Capsule())
	}
}

struct HiboxSoftPill: View {
	let title: String
	var color: Color = HiboxTheme.blue
	var icon: String?

	var body: some View {
		HStack(spacing: 4) {
			if let icon {
				Image(systemName: icon)
					.font(.system(size: 10, weight: .semibold))
			}
			Text(title)
				.font(.caption2.weight(.semibold))
		}
		.foregroundStyle(color)
		.padding(.horizontal, 9)
		.padding(.vertical, 5)
		.background(color.opacity(0.11), in: Capsule())
	}
}

struct HiboxAppIcon: View {
	let url: URL?
	let name: String
	var size: CGFloat = 58

	var body: some View {
		Group {
			if let url {
				LazyImage(url: url) { state in
					if let image = state.image {
						image
							.resizable()
							.aspectRatio(contentMode: .fill)
					} else {
						_placeholder
					}
				}
			} else {
				_placeholder
			}
		}
		.frame(width: size, height: size)
		.clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
				.stroke(Color(hex: "#EDF1F7"), lineWidth: 0.8)
		)
	}

	private var _placeholder: some View {
		ZStack {
			HiboxTheme.softGradient
			Text(String(name.prefix(1)))
				.font(.system(size: size * 0.34, weight: .bold))
				.foregroundStyle(HiboxTheme.blue)
		}
	}
}

struct HiboxEmptyState: View {
	let icon: String
	let title: String
	let message: String
	var actionTitle: String?
	var action: (() -> Void)?

	var body: some View {
		VStack(spacing: 12) {
			ZStack {
				Circle()
					.fill(HiboxTheme.softGradient)
					.frame(width: 88, height: 88)
				Image(systemName: icon)
					.font(.system(size: 32, weight: .medium))
					.foregroundStyle(HiboxTheme.blue)
			}

			Text(title)
				.font(.headline)
				.foregroundStyle(HiboxTheme.text)

			Text(message)
				.font(.footnote)
				.foregroundStyle(HiboxTheme.secondaryText)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
				.padding(.horizontal, 24)

			if let actionTitle, let action {
				Button(action: action) {
					Text(actionTitle)
						.font(.footnote.weight(.semibold))
						.foregroundStyle(.white)
						.padding(.horizontal, 18)
						.padding(.vertical, 10)
						.background(HiboxTheme.gradient, in: Capsule())
				}
				.buttonStyle(.plain)
				.padding(.top, 4)
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 44)
	}
}
