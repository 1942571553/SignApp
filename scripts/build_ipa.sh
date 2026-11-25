#!/usr/bin/env bash
# 本地出未签名 IPA（需要 macOS + Xcode + xcodegen）
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="${BUNDLE_ID:-com.example.signapp}"
APP_NAME="${APP_NAME:-签名助手}"
SERVER_URL="${DEFAULT_SERVER_URL:-}"

echo "==> Bundle ID: ${BUNDLE_ID}"

# 替换占位 Bundle ID
perl -pi -e "s|__BUNDLE_ID__|${BUNDLE_ID}|g" project.yml

# 品牌名
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${APP_NAME}" SignApp/Info.plist
if [ -n "${SERVER_URL}" ]; then
  /usr/libexec/PlistBuddy -c "Set :DefaultServerURL ${SERVER_URL}" SignApp/Info.plist
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "缺少 xcodegen，请先执行：brew install xcodegen"
  exit 1
fi

xcodegen generate

xcodebuild -project SignApp.xcodeproj \
  -scheme SignApp \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build/dd \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  build

mkdir -p build/Payload
rm -rf build/Payload/SignApp.app
cp -R build/dd/Build/Products/Release-iphoneos/SignApp.app build/Payload/
(cd build && rm -f SignApp-unsigned.ipa && zip -qry SignApp-unsigned.ipa Payload)

echo "==> 完成：build/SignApp-unsigned.ipa（未签名，需用证书重签后才能装到真机）"
