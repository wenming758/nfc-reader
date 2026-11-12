#!/usr/bin/env bash
# 在 macOS 上构建未签名 IPA。
# 用法：chmod +x Scripts/build_ipa.sh && ./Scripts/build_ipa.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "错误：需要在 macOS + Xcode 环境中运行。" >&2
  exit 1
fi

BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/DerivedData/Build/Products/Release-iphoneos/NFCReader.app"
OUT_DIR="$BUILD_DIR/ipa"
IPA="$BUILD_DIR/NFCReader-unsigned.ipa"

rm -rf "$BUILD_DIR"
mkdir -p "$OUT_DIR/Payload"

echo "==> 编译 Release（关闭代码签名）"
xcodebuild \
  -project "NFCReader.xcodeproj" \
  -scheme "NFCReader" \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

if [ ! -d "$APP" ]; then
  echo "错误：未找到编译产物 $APP" >&2
  exit 1
fi

echo "==> 打包 Payload"
cp -R "$APP" "$OUT_DIR/Payload/"
rm -rf "$OUT_DIR/Payload/NFCReader.app/_CodeSignature"

(cd "$OUT_DIR" && /usr/bin/zip -qry "$IPA" Payload)

echo "完成：$IPA"
echo "提示：未签名 IPA 需用 Sideloadly / AltStore 配合自己的 Apple 证书重签后才能安装。"
