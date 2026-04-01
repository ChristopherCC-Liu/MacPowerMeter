#!/bin/bash
# create-app-bundle.sh
# 将 swift build 编译产物包装成 macOS .app bundle
#
# 用法: ./create-app-bundle.sh [release|debug]
# 默认: release

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_MODE="${1:-release}"
APP_NAME="MacPowerMeter"
BUNDLE_DIR="${SCRIPT_DIR}/build/${APP_NAME}.app"

# 确定编译产物路径
if [ "$BUILD_MODE" = "release" ]; then
    BUILD_FLAGS="--configuration release"
    BIN_PATH="${SCRIPT_DIR}/.build/release/${APP_NAME}"
else
    BUILD_FLAGS=""
    BIN_PATH="${SCRIPT_DIR}/.build/debug/${APP_NAME}"
fi

echo "==> 编译 ${APP_NAME} (${BUILD_MODE})..."
cd "$SCRIPT_DIR"
swift build $BUILD_FLAGS

if [ ! -f "$BIN_PATH" ]; then
    echo "错误: 编译产物未找到: ${BIN_PATH}"
    exit 1
fi

echo "==> 创建 .app bundle..."

# 清理旧 bundle
rm -rf "$BUNDLE_DIR"

# 创建 bundle 目录结构
mkdir -p "${BUNDLE_DIR}/Contents/MacOS"
mkdir -p "${BUNDLE_DIR}/Contents/Resources"

# 复制可执行文件
cp "$BIN_PATH" "${BUNDLE_DIR}/Contents/MacOS/${APP_NAME}"

# 复制 Info.plist
cp "${SCRIPT_DIR}/MacPowerMeter/Resources/Info.plist" "${BUNDLE_DIR}/Contents/"

# 创建 PkgInfo
echo -n "APPL????" > "${BUNDLE_DIR}/Contents/PkgInfo"

echo "==> .app bundle 创建完成: ${BUNDLE_DIR}"
echo ""
echo "运行方式:"
echo "  open ${BUNDLE_DIR}"
echo ""
echo "或直接执行:"
echo "  ${BUNDLE_DIR}/Contents/MacOS/${APP_NAME}"
