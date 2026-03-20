#!/bin/bash

set -euo pipefail

BRANCH=$(git symbolic-ref --short HEAD)

echo "同步本地分支到远端最新 commit..."
git fetch --prune origin
git pull --ff-only origin "$BRANCH"

echo "清理旧文件..."
rm -rf src/ pkg/ *.pkg.tar.zst

echo "更新版本号 (pkgver)..."
makepkg -od

echo "同步 .SRCINFO..."
makepkg --printsrcinfo >.SRCINFO

echo "提交更改并推送至 AUR..."
git add .

# 获取最新生成的版本号作为 commit message
NEW_VER=$(grep -m1 "pkgver =" .SRCINFO | cut -d' ' -f3)
git commit -m "update to version $NEW_VER" || echo "⚠️ 没有检测到更改，跳过提交"
git push origin "$BRANCH"

echo "--- ✅ 更新完成！当前版本: $NEW_VER ---"
