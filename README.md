# 签名助手 · iOS 客户端（可贴牌）

一个 WebView 壳 App：装到 iPhone 后直接加载你自己的签名站，客户在 App 里完成「上传 IPA → 选证书 → 签名 → 安装」。
配套一条 **GitHub Actions 云打包流水线**，没有 Mac 也能出 `.ipa`。

> 重要：这个 App 只是「入口」，真正的签名是服务器上的 zsign 干的，站点必须先部署好，否则 App 打开是空白页。

---

## 目录结构

```
SignApp/
├─ project.yml                     # XcodeGen 工程描述（不手写 .xcodeproj）
├─ SignApp/
│  ├─ SignApp.swift                # App 入口
│  ├─ RootView.swift               # 首屏：未配置站点 → 配置页；已配置 → 站点页
│  ├─ SetupView.swift              # 输入站点域名（自动补 https）
│  ├─ WebScreen.swift              # 站点页 + 顶部工具条（前进/后退/刷新/更多）
│  ├─ WebView.swift                # WKWebView 封装、itms-services 交给系统、JS 弹窗
│  ├─ ServerConfig.swift           # 域名规范化与持久化
│  ├─ Theme.swift                  # 主题色
│  ├─ Info.plist
│  └─ Assets.xcassets/             # AppIcon（1024×1024）+ AccentColor
├─ .github/workflows/build-ipa.yml # 云打包：签名包 / 未签名包
├─ scripts/build_ipa.sh            # 有 Mac 时本地出未签名包
└─ README.md
```

---

## 一、没有 Mac：用 GitHub Actions 出包（推荐）

### 1. 建仓库并上传

新建一个 **私有仓库**，把 `SignApp/` 里的全部内容放到仓库根目录（`.github`、`SignApp`、`project.yml` 要在根）。

### 2. 配置仓库变量 Variables

`Settings → Secrets and variables → Actions → Variables` 新建：

| 名称 | 必填 | 示例 | 说明 |
|---|---|---|---|
| `BUNDLE_ID` | 是 | `com.mingxin.sign` | 唯一标识，不能和别人的重复 |
| `APP_NAME` | 否 | `明鑫签名` | 桌面显示名，默认「签名助手」 |
| `DEFAULT_SERVER_URL` | 否 | `https://sign.yourdomain.com` | 预置站点，App 首次打开直接进站（不填则让用户自己输） |
| `EXPORT_METHOD` | 否 | `ad-hoc` | `ad-hoc` / `development` / `app-store` |

### 3. 配置签名 Secrets（用自己的开发者账号）

`Settings → Secrets and variables → Actions → Secrets` 新建：

| 名称 | 内容 |
|---|---|
| `TEAM_ID` | 开发者账号的 Team ID（developer.apple.com → Membership 里能看到，10 位） |
| `ASC_KEY_ID` | App Store Connect API Key 的 Key ID |
| `ASC_ISSUER_ID` | Issuer ID（团队密钥页面顶部那串 UUID） |
| `ASC_KEY_P8` | `.p8` 私钥文件的 **Base64** 内容 |

**怎么拿 App Store Connect API Key：**

1. 登录 [App Store Connect](https://appstoreconnect.apple.com) → 「用户和访问」→「集成」→「App Store Connect API」→「团队密钥」
2. 点「生成密钥」，名称随便填，权限选 **Admin** 或 **App Manager**（App Manager 就够签名和描述文件）
3. 下载 `.p8`（**只能下载一次**，丢了只能重新生成）
4. 转 Base64：

**Windows PowerShell**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\AuthKey_XXXX.p8")) | Set-Clipboard
```
**macOS / Linux**
```bash
base64 -i AuthKey_XXXX.p8 | pbcopy     # mac
base64 -w0 AuthKey_XXXX.p8             # linux
```

把输出的长串贴进 `ASC_KEY_P8`。

> 这套方式 Xcode 会自动替你申请开发/分发证书和描述文件，不需要你在网页上手动建证书、也不需要 p12。
> 需要 **付费开发者账号**（$99/年），免费 Apple ID 不支持 API Key。

### 4. 运行

`Actions → Build IPA → Run workflow`，1~5 分钟出包，在 run 页面底部 **Artifacts** 下载 `SignApp-xx.zip`，解压得到 `.ipa`。

没有配置任何签名 Secrets 时，流水线会自动产出 **未签名 ipa**（`SignApp-unsigned.ipa`），只能用于越狱机或 AltStore 自签，无法直接装。

---

## 二、有 Mac：本地打包

```bash
brew install xcodegen
cd SignApp
BUNDLE_ID=com.mingxin.sign APP_NAME=明鑫签名 DEFAULT_SERVER_URL=https://sign.yourdomain.com \
  bash scripts/build_ipa.sh
# 产物：build/SignApp-unsigned.ipa
```

再签名（用你自己的证书）：

```bash
zsign -k dev.p12 -p 证书密码 -m dev.mobileprovision -o SignApp.ipa build/SignApp-unsigned.ipa
```

---

## 三、装到手机上

| 事项 | 说明 |
|---|---|
| **Ad Hoc 分发** | 目标设备的 UDID 必须先在 developer.apple.com →「设备」登记（每种设备类型每年最多 100 台），否则装上就闪退 |
| **首次打开** | 设置 → 通用 → VPN与设备管理 → 信任该开发者 |
| **iOS 16/17** | 设置 → 隐私与安全性 → **开发者模式** → 打开并重启手机（不开发者模式，自签/企业签 App 打不开） |
| **在线安装** | 需要 `itms-services://?action=download-manifest&url=https://.../manifest.plist` 的 HTTPS 页面；Safari 打开才能装 |
| **有线安装** | Windows 可用爱思助手 / Apple Configurator 直接装 ipa |
| **有效期** | 开发者证书 1 年；免费账号 7 天 |

---

## 四、贴牌改动点

| 想改什么 | 改哪里 |
|---|---|
| 桌面图标 | 替换 `SignApp/Assets.xcassets/AppIcon.appiconset/icon.png`（1024×1024，不要透明通道） |
| 应用名称 | 仓库变量 `APP_NAME`，或 `Info.plist` 的 `CFBundleDisplayName` |
| 默认站点 | 仓库变量 `DEFAULT_SERVER_URL`，或 `Info.plist` 的 `DefaultServerURL` |
| 主题色 | `SignApp/Theme.swift` 里的 `accent` |
| 启动图 | `Info.plist` 的 `UILaunchScreen`（先用系统默认，需要再自定义） |

> 客户也能自己在首屏/右上角「更换服务器地址」里改站点，所以一个包可以服务多个域名。

---

## 五、已知边界

1. **App 只是壳**：站点没上线、域名解析不对、证书过期，打开就是白屏或报错——这时点右上角「在 Safari 中打开」能直接看真实错误。
2. **必须 HTTPS**：`Info.plist` 没开 ATS 例外，http 站点会被拦。
3. **上传大文件**：站点侧要放开 Nginx `client_max_body_size`（建议 512m）和 PHP `upload_max_filesize`。App 内上传走系统文件选择器，个别站点用的上传组件在 WKWebView 里可能选不到文件，此时用「在 Safari 中打开」完成上传。
4. **安装跳转**：点站点的「安装」按钮会走 `itms-services://`，App 已经把它交给系统处理（会跳转 Safari 完成安装），这是 iOS 的硬性要求，任何 App 都绕不过。
5. **JS 弹窗**：`alert/confirm` 已接管，`prompt` 未实现（站点别用 prompt）。

---

## 六、安全提醒

- `ASC_KEY_P8`、`TEAM_ID` 只放 GitHub Secrets，**永不提交进仓库**；
- 签名用的 p12 和描述文件不要放在站点公开目录（`/attachment/` 这类能被 URL 直接下载的位置）；
- 企业证书（In-House）对外分发违反 Apple 开发者计划条款，证书随时可能被吊销，客户装好的 App 会集体失效；正规做法是 Ad Hoc（限登记设备）或上架 App Store。
