#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

BRANCH=$(git symbolic-ref --short HEAD)
PKGNAME=$(awk -F= '/^pkgname=/{gsub(/'\''|"/, "", $2); print $2; exit}' PKGBUILD)

echo "同步本地分支到远端最新 commit..."
git fetch --prune origin
git pull --ff-only origin "$BRANCH"

echo "清理旧文件..."
rm -rf src/ pkg/ "$PKGNAME" *.pkg.tar.* *.tar.gz *.tar.xz

echo "刷新源码并重新计算 pkgver..."
makepkg -od

TMP_SRCINFO="$(mktemp)"
trap 'rm -f "$TMP_SRCINFO"' EXIT

makepkg --printsrcinfo >"$TMP_SRCINFO"
NEW_VER=$(awk '$1 == "pkgver" && $2 == "=" { print $3; exit }' "$TMP_SRCINFO")

[ -n "$NEW_VER" ] || {
    echo "❌ 无法从 .SRCINFO 解析 pkgver"
    exit 1
}

echo "同步 PKGBUILD 和 .SRCINFO..."
sed -i "s/^pkgver=.*/pkgver=${NEW_VER}/" PKGBUILD
makepkg --printsrcinfo >.SRCINFO

echo "提交更改并推送至 AUR..."
git add PKGBUILD .SRCINFO
git commit -m "update to version $NEW_VER" || echo "⚠️ 没有检测到更改，跳过提交"
git push origin "$BRANCH"

echo "--- ✅ 更新完成！当前版本: $NEW_VER ---"
