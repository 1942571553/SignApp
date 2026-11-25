//
//  TabEnum.swift
//  feather
//
//  Created by samara on 22.03.2025.
//

import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
	case home
	case library
	case tools
	case settings
	
	var title: String {
		switch self {
		case .home:			return "首页"
		case .library:		return "应用"
		case .tools:		return "工具"
		case .settings:		return "我的"
		}
	}
	
	var icon: String {
		switch self {
		case .home:			return "house.fill"
		case .library:		return "square.grid.2x2.fill"
		case .tools:		return "wrench.and.screwdriver.fill"
		case .settings:		return "person.crop.circle.fill"
		}
	}
	
	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
		case .home:			HomeView()
		case .library:		LibraryView()
		case .tools:		ToolsView()
		case .settings:		SettingsView()
		}
	}
	
	static var defaultTabs: [TabEnum] {
		return [
			.home,
			.library,
			.tools,
			.settings
		]
	}
	
	static var customizableTabs: [TabEnum] {
		return []
	}
}
