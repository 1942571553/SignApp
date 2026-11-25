# 芒果签名（MangoSign）

基于开源项目 [Feather](https://github.com/claration/Feather)（GPL-3.0）二次开发的 iOS 端签名工具。保留设备内导入 ipa / p12 / mobileprovision、zsign 重签、导出与安装能力，并新增「远程品牌配置」。

## 与原版的差异

- 显示名称改为「芒果签名」，Bundle ID 改为 `com.mangosign.app`
- 全新 App 图标与主题色（墨绿 → 芒果橙）
- 新增 `Feather/Backend/Remote/BrandConfig.swift`：启动时拉取品牌配置
- 首页顶部显示后台配置的公告，并可跳转客服链接
- 设置页新增「服务器」：可填配置接口地址、手动同步、查看同步状态与错误
- 设置页去掉原作者赞助/反馈入口，改为「联系客服」「开源声明」
- 关于页保留原作者 Credits，并注明本版本基于 Feather（GPL-3.0）修改

## 远程配置接口

App 请求：

```
GET https://sign.yxy1.cc/api/config?token=yixiangdz2026sign
```

返回（与 `brandd` 品牌服务一致）：

```json
{
  "ok": true,
  "brand": {
    "app_name": "芒果签名",
    "app_title": "芒果签名",
    "subtitle": "在手机上离线重签",
    "theme_color": "#E8933A",
    "announcement": "公告内容",
    "support_url": "https://你的域名",
    "logo_url": ""
  },
  "client": {
    "version": "1.0.0",
    "download_url": "",
    "min_version": "",
    "force_update": false,
    "allow_sign": true,
    "allow_install": true
  }
}
```

默认地址写在 `Feather/Backend/Remote/BrandConfig.swift` 的 `defaultConfigURL`，也可在 App 设置里直接改，改完点「同步远程配置」立即生效。配置会缓存到 UserDefaults，断网时用上次缓存。

## 构建

推送到 `main` 且改动 `MangoSign/**` 时，GitHub Actions 自动编译未签名 ipa，产物在 Release `mangosign-<run>`。

本地构建（需要 macOS + Xcode）：

```bash
xcodebuild -project Feather.xcodeproj -scheme Feather \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

## 安装

仓库里的 ipa 是**未签名**包，必须用你自己的 Apple 开发者证书重签后再装：

1. 用 `brandd` 后台上传这个 ipa + 你的 p12 / mobileprovision，生成签名包
2. iPhone Safari 打开安装页安装
3. 或者导入本 App 里，选证书后在本机重签并安装（需配对文件/越狱通道，取决于设备）

只可用于自己的 App、自己的证书、自己的测试设备。

## 许可证

GPL-3.0，见 `LICENSE`。本目录的修改同样按 GPL-3.0 提供源码；分发时请保留许可证与原作者声明。修改记录见 `NOTICE.md`。
