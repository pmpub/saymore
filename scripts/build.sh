#!/bin/sh
# 一键构建：解析依赖(走 GitHub 加速器) → 构建 Release → 统一重签 → 装到 /Applications → 启动
# 用法：sh scripts/build.sh
set -e
cd "$(dirname "$0")/.."
DD=.local-build
APP_OUT="$DD/Build/Products/Release/Saymore.app"
DEST=/Applications/Saymore.app
ENT="$PWD/VoiceInk/VoiceInk.local.entitlements"
# 优先用 Developer ID（和分发版 DMG 同一身份，系统权限授权不会因换包失效），没有再退回 Apple Development
ID=$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application:/ {print $2; exit}')
[ -n "$ID" ] || ID=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development:/ {print $2; exit}')
[ -n "$ID" ] || { echo "没有可用的签名身份"; exit 1; }
echo "签名身份：$ID"
[ -d "$HOME/VoiceInk-Dependencies/whisper.cpp/build-apple/whisper.xcframework" ] || { echo "先跑 make whisper（需要 brew install cmake）"; exit 1; }

# 临时 git 配置：github.com → gh-proxy.com 加速；不改全局 ~/.gitconfig
GC=$(mktemp); printf '[url "https://gh-proxy.com/https://github.com/"]\n\tinsteadOf = https://github.com/\n' > "$GC"
export GIT_CONFIG_GLOBAL="$GC"; unset HTTPS_PROXY HTTP_PROXY https_proxy http_proxy

xcodebuild -project VoiceInk.xcodeproj -scheme VoiceInk -configuration Release \
  -derivedDataPath "$DD" -xcconfig LocalBuild.xcconfig \
  -skipPackagePluginValidation -skipMacroValidation \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES DEVELOPMENT_TEAM="" \
  CODE_SIGN_ENTITLEMENTS="$ENT" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LOCAL_BUILD' build | grep -E "error:|warning: .*deprecated|\*\* BUILD" || true
[ -d "$APP_OUT" ] || { echo "构建失败"; exit 1; }
rm -f "$GC"

# 从里到外统一用开发者身份签名（hardened runtime 下 Team ID 必须一致，否则启动即崩）
APP="$APP_OUT"
for p in \
  "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc" \
  "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc" \
  "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app" \
  "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" \
  "$APP"/Contents/Frameworks/*.framework \
  "$APP"/Contents/XPCServices/*.xpc; do
  [ -e "$p" ] && codesign --force --sign "$ID" --preserve-metadata=entitlements,flags --timestamp=none "$p" 2>/dev/null
done
codesign --force --sign "$ID" --options runtime --entitlements "$ENT" --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"

pkill -x Saymore 2>/dev/null || true; sleep 1
rm -rf "$DEST"; ditto "$APP" "$DEST"; xattr -cr "$DEST"
open "$DEST"; echo "已安装并启动：$DEST"
