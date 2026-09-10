#!/bin/sh
# 打包可分发的 Saymore DMG。
#   sh scripts/package-dmg.sh            → 构建 + 签名 + DMG（未公证，收件人需"仍要打开"一次）
#   sh scripts/package-dmg.sh --no-build → 不重新构建，重签 + 公证 + DMG
#   sh scripts/package-dmg.sh --dmg-only → 不重新构建也不重签，只重做 DMG（换图标/说明时用）
#   有 "Developer ID Application" 证书 + notarytool 档案（默认名 saymore-notary）时自动公证并 staple。
set -e
cd "$(dirname "$0")/.."
NAME=Saymore
APP=".local-build/Build/Products/Release/$NAME.app"
NOTARY_PROFILE="${NOTARY_PROFILE:-saymore-notary}"
ENT="$PWD/VoiceInk/VoiceInk.local.entitlements"

DMG_ONLY=0; NO_BUILD=0
[ "${1:-}" = "--dmg-only" ] && DMG_ONLY=1
[ "${1:-}" = "--no-build" ] && NO_BUILD=1
if [ $DMG_ONLY -eq 0 ] && [ $NO_BUILD -eq 0 ]; then
  sh scripts/build.sh >/dev/null        # 构建 + Apple Development 签名（同时装到本机 /Applications）
fi
[ -d "$APP" ] || { echo "找不到 $APP"; exit 1; }
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
OUT=~/Desktop/$NAME-$VERSION.dmg

DEVID=$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application:/ {print $2; exit}')
if [ $DMG_ONLY -eq 1 ]; then
  echo "== --dmg-only：复用已签名/已公证的 $APP"
elif [ -n "$DEVID" ]; then
  echo "== 用 Developer ID 重签：$DEVID"
  for p in "$APP"/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/*.xpc "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app" "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" "$APP"/Contents/Frameworks/*.framework "$APP"/Contents/XPCServices/*.xpc; do
    [ -e "$p" ] || continue
    # 剥掉 Xcode 注入的 get-task-allow（公证不接受），其余 entitlements 原样保留
    E=$(mktemp).plist
    if codesign -d --entitlements :- "$p" 2>/dev/null | plutil -convert xml1 -o "$E" - 2>/dev/null && [ -s "$E" ]; then
      /usr/libexec/PlistBuddy -c "Delete :com.apple.security.get-task-allow" "$E" 2>/dev/null || true
      if [ "$(/usr/libexec/PlistBuddy -c Print "$E" 2>/dev/null | grep -c ' = ')" -gt 0 ]; then
        codesign --force --sign "$DEVID" --options runtime --timestamp --entitlements "$E" "$p"
      else
        codesign --force --sign "$DEVID" --options runtime --timestamp "$p"
      fi
    else
      codesign --force --sign "$DEVID" --options runtime --timestamp "$p"
    fi
    rm -f "$E"
  done
  codesign --force --sign "$DEVID" --options runtime --timestamp --entitlements "$ENT" "$APP"
  codesign --verify --deep --strict "$APP"
  if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "== 公证中（可能要几分钟）"
    ZIP=$(mktemp -d)/$NAME.zip; ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
  else
    echo "== 没有 notarytool 档案 $NOTARY_PROFILE，跳过公证（先跑 make release-setup 或 xcrun notarytool store-credentials $NOTARY_PROFILE）"
  fi
else
  echo "== 本机没有 Developer ID Application 证书，DMG 未公证：收件人首次打开需 系统设置→隐私与安全性→仍要打开"
fi

STAGE=$(mktemp -d); cp -R "$APP" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/安装说明.txt" <<TXT
Saymore 安装
1. 把 Saymore 拖进 Applications。
2. 首次打开若提示"无法验证开发者"：系统设置 → 隐私与安全性 → 页面底部点"仍要打开"（只需一次）。
3. 允许 麦克风 / 辅助功能 / 输入监控 三个权限。
4. Settings → AI Enhancement 选 DeepSeek，填自己的 API key（https://platform.deepseek.com/api_keys），模型 deepseek-chat。
5. Settings → Modes：识别模型选 Apple Speech（macOS 26+）或在模型库下载 SenseVoice Small；语言选中文，不要选 auto；AI Enhancement 打开。
6. 快捷键推荐右 Option；用 Fn 需在 系统设置→键盘 把"按下🌐键时"改为"不执行任何操作"。
本软件基于 GPL v3 开源项目 VoiceInk 修改，源码：https://github.com/pmpub/saymore
TXT
ICNS="$APP/Contents/Resources/AppIcon.icns"
cp "$ICNS" "$STAGE/.VolumeIcon.icns"
rm -f "$OUT"; RW=$(mktemp -d)/rw.dmg
hdiutil create -volname "$NAME" -srcfolder "$STAGE" -ov -format UDRW "$RW" >/dev/null
MNT=$(hdiutil attach -nobrowse -readwrite "$RW" | awk -F'\t' '/\/Volumes\//{print $NF}')
SetFile -a C "$MNT"                                   # 卷图标：挂载后显示 S
hdiutil detach "$MNT" -quiet
hdiutil convert "$RW" -format UDZO -o "$OUT" >/dev/null; rm -rf "$STAGE" "$(dirname "$RW")"
if [ -n "$DEVID" ]; then codesign --force --sign "$DEVID" --timestamp "$OUT"; fi
cat > /tmp/seticon.swift <<'SW'
import AppKit
let a = CommandLine.arguments
let img = NSImage(contentsOfFile: a[1])!
print(NSWorkspace.shared.setIcon(img, forFile: a[2], options: []) ? "dmg file icon set" : "dmg file icon FAILED")
SW
swift /tmp/seticon.swift "$ICNS" "$OUT" 2>/dev/null; rm -f /tmp/seticon.swift
echo "DMG: $OUT ($(du -h "$OUT" | cut -f1))"
spctl -a -vv -t install "$APP" 2>&1 | tail -2 || true
