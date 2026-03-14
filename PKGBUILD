# Maintainer: lightjunction <lightjunction.me@gmail.com>
pkgname=astrbot-git
_pkgname=astrbot
pkgver=4.20.0.r1.ga8ff2b3d9
pkgrel=1
pkgdesc="Agentic IM Chatbot infrastructure with uv-managed dependencies. Your clawdbot alternative."
arch=('any')
url="https://github.com/AstrBotDevs/AstrBot"
license=('AGPL-3.0-only')
depends=('python' 'uv')
makedepends=('git')
provides=("${_pkgname}")
conflicts=("${_pkgname}")
source=("${pkgname}::git+${url}.git")
sha256sums=('SKIP')
install=astrbot-git.install

pkgver() {
    cd "$pkgname"
    git describe --long --tags | sed 's/\([^-]*-g\)/r\1/;s/-/./g' | sed 's/^v//g'
}

package() {
    cd "$pkgname"
    local _app_dir="/opt/$_pkgname"

    mkdir -p "$pkgdir$_app_dir"
    cp -r astrbot scripts pyproject.toml LICENSE README.md "$pkgdir$_app_dir/"

    mkdir -p "$pkgdir/usr/bin"
    cat >"$pkgdir/usr/bin/astrbot" <<'EOF'
#!/bin/sh
DATA_ROOT="$HOME/.local/share/astrbot"
ENV_DIR="$HOME/.cache/astrbot"
APP_SOURCE="/opt/astrbot"

mkdir -p "$DATA_ROOT/data"
mkdir -p "$ENV_DIR"

rm -rf "$ENV_DIR/pyproject.toml" "$ENV_DIR/astrbot" "$ENV_DIR/scripts" "$ENV_DIR/README.md" "$ENV_DIR/data"

ln -sf "$APP_SOURCE/pyproject.toml" "$ENV_DIR/pyproject.toml"
ln -sf "$APP_SOURCE/astrbot"        "$ENV_DIR/astrbot"
ln -sf "$APP_SOURCE/scripts"        "$ENV_DIR/scripts"
ln -sf "$APP_SOURCE/README.md"      "$ENV_DIR/README.md"
ln -sfn "$DATA_ROOT/data"           "$ENV_DIR/data"

export UV_PROJECT_ENVIRONMENT="$ENV_DIR/venv"
export UV_CACHE_DIR="$ENV_DIR/uv_cache"

cd "$ENV_DIR" && uv run --python 3.13 astrbot "$@"
EOF

    chmod +x "$pkgdir/usr/bin/astrbot"

    install -Dm644 "scripts/astrbot.service" "$pkgdir/usr/lib/systemd/user/astrbot.service"
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
