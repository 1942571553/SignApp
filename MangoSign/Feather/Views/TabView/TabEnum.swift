//
//  TabEnum.swift
//  feather
//
//  Created by samara on 22.03.2025.
//

import SwiftUI
import NimbleViews

/// 参考 ABox / 嗨签的四段式结构：应用、已签名、工具、我的
enum TabEnum: String, CaseIterable, Hashable {
	case apps
	case signed
	case tools
	case profile

	var title: String {
		switch self {
		case .apps:			return "应用"
		case .signed:		return "已签名"
		case .tools:		return "工具"
		case .profile:		return "我的"
		}
	}

	var icon: String {
		switch self {
		case .apps:			return "square.grid.2x2.fill"
		case .signed:		return "checkmark.seal.fill"
		case .tools:		return "wrench.and.screwdriver.fill"
		case .profile:		return "person.crop.circle.fill"
		}
	}

	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
		case .apps:			AppListView(mode: .apps)
		case .signed:		AppListView(mode: .signed)
		case .tools:		ToolsView()
		case .profile:		SettingsView()
		}
	}

	static var defaultTabs: [TabEnum] {
		return [
			.apps,
			.signed,
			.tools,
			.profile
		]
	}

	static var customizableTabs: [TabEnum] {
		return []
	}
}
