MangoSign（艺祥签）
====================

本目录是 Feather（https://github.com/claration/Feather，GPL-3.0）的修改版本，
修改日期：2026-11-25。

修改内容：
1. Feather.xcconfig：Bundle ID 由 thewonderofyou.Feather 改为 com.yixiangsign.app，版本号 1.0.0
2. Feather.xcodeproj：CFBundleDisplayName 改为「艺祥签」
3. Feather/Resources/Assets.xcassets/AppIcon.appiconset：替换 App 图标
4. Feather/Resources/AppIcon.icon：替换图标资源与渐变色
5. 默认主题色由 #848ef9 改为 #E8933A
6. 新增 Feather/Backend/Remote/BrandConfig.swift（远程品牌配置）
7. Feather/Views/Library/LibraryView.swift：首页公告与客服入口
8. Feather/Views/Settings/SettingsView.swift：服务器配置、客服、开源声明
9. Feather/Views/Settings/About/AboutView.swift：显示名称与 GPL 声明，移除赞助图
10. Feather/FeatherApp.swift：启动时同步远程配置并应用主题色

原项目版权归其作者所有；本修改版本同样以 GPL-3.0 发布，完整源码随本仓库提供。
