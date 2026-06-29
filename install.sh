#!/usr/bin/env bash
# reasflow 一句话安装器。
# 用法（用户侧）：
#   curl -fsSL https://raw.githubusercontent.com/<OWNER>/<REPO>/main/install.sh | sh
#
# 行为：探测平台/架构 → 经 /releases/latest 重定向取最新 tag（不走 api.github.com，
#       不受未授权 API 限流影响）→ 从 releases/download/<tag>/ 下载对应 tarball
#       → 校验 sha256 → 解压到 ${INSTALL_DIR}（默认 ~/.local/bin）→ 提示 PATH。
set -euo pipefail

# ===== 改这一行：公开 release 仓的 owner/name =====
RELEASE_REPO="${RELEASE_REPO:-sillyDaibo/reasflow-release}"
# =================================================

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

uname_s="$(uname -s)"
uname_m="$(uname -m)"
case "${uname_s}-${uname_m}" in
    Linux-x86_64|Linux-amd64)   asset_pattern="x86_64-linux"      ; bin=reasflow ;;
    Linux-aarch64|Linux-arm64)  asset_pattern="aarch64-linux"     ; bin=reasflow ;;
    Darwin-x86_64)              asset_pattern="universal2-macos"  ; bin=reasflow ;;
    Darwin-arm64)               asset_pattern="universal2-macos"  ; bin=reasflow ;;
    MINGW*-*|MSYS*-*|CYGWIN*-*) asset_pattern="x86_64-windows"    ; bin=reasflow.exe ;;
    *) echo "✗ 不支持的平台：${uname_s}-${uname_m}" >&2; exit 1 ;;
esac

# tag → asset 文件名（由 tag 拼接，无需 API）
ver_from_tag() {
    # /releases/latest 302 → /releases/tag/<tag>，取 Location 头里的 tag
    local loc
    loc="$(curl -fsSI "https://github.com/${RELEASE_REPO}/releases/latest" | grep -i '^location:' | tr -d '\r' | awk '{print $2}')"
    basename "${loc}"
}

echo "==> reasflow 安装器"
echo "    平台: ${uname_s}/${uname_m}  → asset: *${asset_pattern}*"
echo "    目标: ${INSTALL_DIR}"

echo "==> 查询最新 release：${RELEASE_REPO}"
tag="$(ver_from_tag)"
[ -n "$tag" ] || { echo "✗ 解析最新 tag 失败" >&2; exit 1; }
echo "    最新版本: ${tag}"

base="https://github.com/${RELEASE_REPO}/releases/download/${tag}"
asset_name="reasflow-${tag}-${asset_pattern}"
case "$asset_pattern" in
    x86_64-windows) asset_name="${asset_name}.zip" ;;
    *)              asset_name="${asset_name}.tar.gz" ;;
esac
asset_url="${base}/${asset_name}"
echo "    下载: ${asset_name}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
archive="$tmp/${asset_name}"
curl -fsSL -o "$archive" "$asset_url"

# 校验 sha256（从同一 release 拉 sha256sums.txt）
sums_url="${base}/sha256sums.txt"
if expected="$(curl -fsSL "$sums_url" | grep -E " ${asset_name}\$" | awk '{print $1}')"; then
    if [ -n "$expected" ]; then
        actual="$(sha256sum "$archive" | awk '{print $1}')"
        if [ "$expected" != "$actual" ]; then
            echo "✗ sha256 校验失败：预期 $expected 实得 $actual" >&2
            exit 1
        fi
        echo "    sha256 校验通过"
    fi
fi

# 解压
mkdir -p "$INSTALL_DIR"
case "$archive" in
    *.tar.gz) tar -xzf "$archive" -C "$tmp" ;;
    *.zip)    command -v unzip >/dev/null || { echo "✗ 需要 unzip" >&2; exit 1; }; unzip -q "$archive" -d "$tmp" ;;
esac

found="$(find "$tmp" -type f -name "$bin" | head -1)"
[ -n "$found" ] || { echo "✗ 解压后未找到 ${bin}" >&2; exit 1; }

install -m 0755 "$found" "${INSTALL_DIR}/${bin}"
echo "==> 已安装：${INSTALL_DIR}/${bin}"

case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *)
        echo
        echo "⚠  ${INSTALL_DIR} 不在 PATH 中。请加入 shell 配置："
        echo "    export PATH=\"${INSTALL_DIR}:\$PATH\""
        ;;
esac

echo
echo "==> 完成。验证："
echo "    ${INSTALL_DIR}/${bin} --version"
echo "    cd <你的项目> && ${bin} init"
