#!/usr/bin/env bash
# reasflow 一句话安装器。
# 用法（用户侧）：
#   curl -fsSL https://raw.githubusercontent.com/<OWNER>/<REPO>/main/install.sh | sh
#
# 行为：探测平台/架构 → 查询 GitHub 最新 release → 下载对应 tarball
#       → 校验 sha256 → 解压到 ${INSTALL_DIR}（默认 ~/.local/bin）→ 提示 PATH。
set -euo pipefail

# ===== 改这一行：公开 release 仓的 owner/name =====
RELEASE_REPO="${RELEASE_REPO:-sillyDaibo/reasflow-release}"
# =================================================

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

# 平台 → release asset 匹配
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

echo "==> reasflow 安装器"
echo "    平台: ${uname_s}/${uname_m}  → asset: *${asset_pattern}*"
echo "    目标: ${INSTALL_DIR}"

api="https://api.github.com/repos/${RELEASE_REPO}/releases/latest"
echo "==> 查询最新 release：${RELEASE_REPO}"
if ! release_json="$(curl -fsSL "$api")"; then
    echo "✗ 无法获取 release 信息，检查 RELEASE_REPO=${RELEASE_REPO} 是否正确" >&2
    exit 1
fi

tag="$(printf '%s' "$release_json" | grep -m1 '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')"
[ -n "$tag" ] || { echo "✗ 解析 tag_name 失败" >&2; exit 1; }
echo "    最新版本: ${tag}"

# 找匹配的 asset（取 browser_download_url）
asset_url="$(printf '%s' "$release_json" \
    | grep '"browser_download_url"' \
    | grep -E "/[^/]*${asset_pattern}\.(tar\.gz|zip)\b" \
    | head -1 \
    | sed -E 's/.*"([^"]+)".*/\1/')"
[ -n "$asset_url" ] || { echo "✗ release ${tag} 中没有匹配 *${asset_pattern} 的产物" >&2; exit 1; }
echo "    下载: ${asset_url##*/}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
archive="$tmp/${asset_url##*/}"
curl -fsSL -o "$archive" "$asset_url"

# 校验 sha256（若 release 带 sha256sums.txt 则下载并核对）
sums_url="$(printf '%s' "$release_json" \
    | grep '"browser_download_url"' \
    | grep -E '/sha256sums\.txt"' \
    | head -1 \
    | sed -E 's/.*"([^"]+)".*/\1/')"
if [ -n "$sums_url" ]; then
    expected="$(curl -fsSL "$sums_url" | grep -E " ${asset_url##*/}\$" | awk '{print $1}')"
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

# 找解压出来的二进制（可能在子目录）
found="$(find "$tmp" -type f -name "$bin" -perm -u+x | head -1)"
[ -n "$found" ] || found="$(find "$tmp" -type f -name "$bin" | head -1)"
[ -n "$found" ] || { echo "✗ 解压后未找到 ${bin}" >&2; exit 1; }

install -m 0755 "$found" "${INSTALL_DIR}/${bin}"
echo "==> 已安装：${INSTALL_DIR}/${bin}"

# PATH 检查
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
