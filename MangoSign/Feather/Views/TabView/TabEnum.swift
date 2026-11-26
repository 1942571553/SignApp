//
//  TabEnum.swift
//  feather
//
//  Created by samara on 22.03.2025.
//

import SwiftUI
import NimbleViews

/// ABox 五段式结构：应用、已签名、文件、下载、设置
enum TabEnum: String, CaseIterable, Hashable {
	case apps
	case signed
	case files
	case downloads
	case settings

	var title: String {
		switch self {
		case .apps:			return "应用"
		case .signed:		return "已签名"
		case .files:		return "文件"
		case .downloads:	return "下载"
		case .settings:		return "设置"
		}
	}

	var icon: String {
		switch self {
		case .apps:			return "chevron.left.forwardslash.chevron.right"
		case .signed:		return "square.stack.3d.up.fill"
		case .files:		return "folder.fill"
		case .downloads:	return "arrow.down.circle.fill"
		case .settings:		return "gearshape.fill"
		}
	}

	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
		case .apps:			StoreView()
		case .signed:		SignedAppsView()
		case .files:		FilesView()
		case .downloads:		DownloadsView()
		case .settings:		SettingsView()
		}
	}

	static var defaultTabs: [TabEnum] {
		return [
			.apps,
			.signed,
			.files,
			.downloads,
			.settings
		]
	}

	static var customizableTabs: [TabEnum] {
		return []
	}
}
