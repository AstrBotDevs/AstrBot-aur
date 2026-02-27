#!/bin/bash

set -e
echo "清理旧文件..."
rm -rf src/ pkg/ *.pkg.tar.zst

echo "更新版本号 (pkgver)..."
makepkg -od

echo "同步 .SRCINFO..."
makepkg --printsrcinfo >.SRCINFO

echo "提交更改并推送至 AUR..."
git add PKGBUILD .SRCINFO .gitignore *.install
# 获取最新生成的版本号作为 commit message
NEW_VER=$(grep -m1 "pkgver =" .SRCINFO | cut -d' ' -f3)
git commit -m "update to version $NEW_VER"
git push origin master

echo "--- ✅ 更新完成！当前版本: $NEW_VER ---"
