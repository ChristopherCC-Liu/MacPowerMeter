#!/bin/bash
# install.sh — 一键编译、安装、配置 CLI 命令
#
# 用法:
#   ./install.sh          安装到 /Applications 并创建 CLI 命令
#   ./install.sh uninstall 卸载应用和 CLI 命令

set -euo pipefail

APP_NAME="MacPowerMeter"
CLI_NAME="powermeter"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="/Applications"
CLI_PATH="/usr/local/bin/${CLI_NAME}"

# ── 卸载 ──────────────────────────────────────
if [ "${1:-}" = "uninstall" ]; then
    echo "==> 卸载 ${APP_NAME}..."
    [ -d "${INSTALL_DIR}/${APP_NAME}.app" ] && rm -rf "${INSTALL_DIR}/${APP_NAME}.app" && echo "    已移除 ${INSTALL_DIR}/${APP_NAME}.app"
    [ -f "$CLI_PATH" ] && sudo rm -f "$CLI_PATH" && echo "    已移除 ${CLI_PATH}"
    echo "==> 卸载完成"
    exit 0
fi

# ── 编译 ──────────────────────────────────────
echo "==> 编译 ${APP_NAME} (release)..."
cd "$SCRIPT_DIR"
swift build --configuration release

BIN_PATH="${SCRIPT_DIR}/.build/release/${APP_NAME}"
if [ ! -f "$BIN_PATH" ]; then
    echo "错误: 编译产物未找到: ${BIN_PATH}"
    exit 1
fi

# ── 创建 .app bundle ─────────────────────────
echo "==> 创建 .app bundle..."
BUNDLE_DIR="${SCRIPT_DIR}/build/${APP_NAME}.app"
rm -rf "$BUNDLE_DIR"
mkdir -p "${BUNDLE_DIR}/Contents/MacOS"
mkdir -p "${BUNDLE_DIR}/Contents/Resources"

cp "$BIN_PATH" "${BUNDLE_DIR}/Contents/MacOS/${APP_NAME}"
cp "${SCRIPT_DIR}/MacPowerMeter/Resources/Info.plist" "${BUNDLE_DIR}/Contents/"
echo -n "APPL????" > "${BUNDLE_DIR}/Contents/PkgInfo"

# ── 安装到 /Applications ────────────────────
echo "==> 安装到 ${INSTALL_DIR}..."
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
    # 先关闭正在运行的实例
    osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || true
    sleep 1
    rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi
cp -R "$BUNDLE_DIR" "${INSTALL_DIR}/"

# ── 创建 CLI 命令 ────────────────────────────
echo "==> 创建 CLI 命令: ${CLI_NAME}..."
sudo mkdir -p /usr/local/bin

cat <<'WRAPPER' | sudo tee "$CLI_PATH" > /dev/null
#!/bin/bash
# powermeter — MacPowerMeter CLI launcher
case "${1:-}" in
    stop|quit|exit)
        osascript -e 'tell application "MacPowerMeter" to quit' 2>/dev/null
        echo "MacPowerMeter 已停止"
        ;;
    status)
        if pgrep -x MacPowerMeter > /dev/null; then
            echo "MacPowerMeter 正在运行 (PID: $(pgrep -x MacPowerMeter))"
        else
            echo "MacPowerMeter 未运行"
        fi
        ;;
    -h|--help|help)
        echo "用法: powermeter [command]"
        echo ""
        echo "命令:"
        echo "  (无参数)    启动 MacPowerMeter"
        echo "  stop        停止 MacPowerMeter"
        echo "  status      查看运行状态"
        echo "  help        显示帮助"
        ;;
    *)
        open -a MacPowerMeter
        echo "MacPowerMeter 已启动 (状态栏)"
        ;;
esac
WRAPPER

sudo chmod +x "$CLI_PATH"

echo ""
echo "==> 安装完成!"
echo ""
echo "  启动:   powermeter"
echo "  停止:   powermeter stop"
echo "  状态:   powermeter status"
echo "  卸载:   ./install.sh uninstall"
echo ""
