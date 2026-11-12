#!/bin/bash
# YingXingRoute -> .ipa   (在 macOS + Xcode 上执行)
#
#   MODE=signed   TEAM=XXXXXXXXXX ./build-ipa-macos.sh     # 产出可安装的签名 ipa
#   MODE=unsigned ./build-ipa-macos.sh                     # 产出未签名 ipa（交给 Sideloadly/AltStore 重签）
#   METHOD=development|ad-hoc|app-store|enterprise
#   NO_NFC=1 去掉 NFC entitlement（免费 Apple ID 必须去掉）
#
set -euo pipefail
cd "$(dirname "$0")"

PROJ="YingXingRoute.xcodeproj"
SCHEME="YingXingRoute"
MODE="${MODE:-unsigned}"
TEAM="${TEAM:-}"
BUNDLE_ID="${BUNDLE_ID:-com.fyguiji.prp.ios}"
METHOD="${METHOD:-development}"
BUILD_DIR="build"
EXPORT_DIR="$BUILD_DIR/ipa"

rm -rf "$BUILD_DIR"; mkdir -p "$BUILD_DIR"

XCODE_VER=$(xcodebuild -version | head -1 | awk '{print $2}')
echo "== Xcode $XCODE_VER / scheme $SCHEME / mode $MODE =="

COMMON_SETTINGS=(
  -project "$PROJ"
  -scheme "$SCHEME"
  -configuration Release
  -sdk iphoneos
  -destination 'generic/platform=iOS'
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
)

if [ "$NO_NFC" = "1" ]; then
  COMMON_SETTINGS+=(CODE_SIGN_ENTITLEMENTS=)
fi

if [ "$MODE" = "signed" ]; then
  [ -z "$TEAM" ] && { echo "签名模式必须给 TEAM=<TeamID>"; exit 1; }
  xcodebuild "${COMMON_SETTINGS[@]}" \
    -archivePath "$BUILD_DIR/$SCHEME.xcarchive" \
    DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic \
    -allowProvisioningUpdates archive

  cat > "$BUILD_DIR/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>$METHOD</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>stripSwiftSymbols</key><true/>
  <key>compileBitcode</key><false/>
  <key>destination</key><string>export</string>
</dict>
</plist>
EOF

  xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$SCHEME.xcarchive" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates
else
  # 未签名: 直接 build，把 .app 打进 Payload/ 手工封 IPA
  xcodebuild "${COMMON_SETTINGS[@]}" \
    -derivedDataPath "$BUILD_DIR/dd" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
    build
  APP=$(find "$BUILD_DIR/dd/Build/Products/Release-iphoneos" -maxdepth 1 -name "*.app" | head -1)
  [ -z "$APP" ] && { echo "构建产物未找到"; exit 1; }
  mkdir -p "$EXPORT_DIR/Payload"
  cp -R "$APP" "$EXPORT_DIR/Payload/"
  ( cd "$EXPORT_DIR" && zip -qry "$SCHEME-unsigned.ipa" Payload )
  echo "未签名 IPA: $EXPORT_DIR/$SCHEME-unsigned.ipa"
  echo "装到手机: Sideloadly / AltStore / TrollStore(视 iOS 版本) 重签后安装"
fi

ls -lh "$EXPORT_DIR"/*.ipa
echo "== DONE =="
