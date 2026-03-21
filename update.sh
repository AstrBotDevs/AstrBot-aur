#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

BRANCH=$(git symbolic-ref --short HEAD)
PKGNAME=$(awk -F= '/^pkgname=/{gsub(/'\''|"/, "", $2); print $2; exit}' PKGBUILD)

echo "同步本地分支到远端最新 commit..."
git fetch --prune origin
git pull origin "$BRANCH" || {
    echo "⚠️ Pull failed (可能存在本地分支分歧)，正在尝试 rebase..."
    git pull --rebase origin "$BRANCH" || {
        echo "❌ Pull 失败，请手动解决冲突："
        echo "   cd $SCRIPT_DIR"
        echo "   git status"
        echo "   git rebase --abort  # 如需放弃"
        exit 1
    }
}

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

OLD_VER=$(awk -F= '/^pkgver=/{gsub(/'\''|"/, "", $2); print $2; exit}' PKGBUILD)
OLD_PKGREL=$(awk -F= '/^pkgrel=/{gsub(/'\''|"/, "", $2); print $2; exit}' PKGBUILD)

if [ "$NEW_VER" != "$OLD_VER" ]; then
    echo "检测到新版本，重置 pkgrel..."
    NEW_PKGREL=1
else
    echo "版本未变，递增 pkgrel..."
    NEW_PKGREL=$((OLD_PKGREL + 1))
fi

echo "同步 PKGBUILD 和 .SRCINFO..."
sed -i "s/^pkgver=.*/pkgver=${NEW_VER}/" PKGBUILD
sed -i "s/^pkgrel=.*/pkgrel=${NEW_PKGREL}/" PKGBUILD
makepkg --printsrcinfo >.SRCINFO

echo "提交更改并推送至 AUR 和GITHUB镜像..."
git add .
git commit -m "update to version $NEW_VER-$NEW_PKGREL" || echo "⚠️ 没有检测到更改，跳过提交"
git push origin "$BRANCH"
git push github "$BRANCH"
echo "--- ✅ 更新完成！当前版本: $NEW_VER-$NEW_PKGREL ---"
