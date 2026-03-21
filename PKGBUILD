# Maintainer: lightjunction <lightjunction.me@gmail.com>

pkgname=astrbot-git
_pkgname=astrbot
pkgver=0.0.0.r1.g43e1070
pkgrel=1
pkgdesc="Agentic IM Chatbot infrastructure (multi-instance, astrbotctl only)"
arch=('any')
url="https://github.com/AstrBotDevs/AstrBot"
license=('AGPL-3.0-only')

depends=('python' 'uv' 'git' 'certbot')
makedepends=('git')

provides=("$_pkgname")
conflicts=("$_pkgname")

source=(
    "astrbotctl"
    "astrbot@.service"
    "config.template"
)

sha256sums=('SKIP' 'SKIP' 'SKIP')

install=astrbot-git.install

prepare() {
    msg2 "Shallow cloning AstrBot repository..."
    git clone --depth=1 --branch=dev \
        "https://github.com/AstrBotDevs/AstrBot.git" \
        "$srcdir/$_pkgname"
}

pkgver() {
    cd "$srcdir/$_pkgname"
    local _ver
    _ver=$(git describe --long --tags 2>/dev/null) ||
        _ver=""
    if [ -z "$_ver" ]; then
        # Shallow clone fallback: use commit count and hash
        echo "0.0.0.r$(git rev-list --count HEAD).g$(git rev-parse --short HEAD)"
    else
        echo "$_ver" | sed 's/\([^-]*-g\)/r\1/;s/-/./g' | sed 's/^v//g'
    fi
}

package() {
    cd "$srcdir/$_pkgname"

    local _appdir="/opt/$_pkgname"

    install -d "$pkgdir$_appdir"
    cp -r astrbot scripts pyproject.toml README.md LICENSE "$pkgdir$_appdir/"

    install -Dm644 "$srcdir/config.template" "$pkgdir$_appdir/config.template"

    install -Dm755 "$srcdir/astrbotctl" \
        "$pkgdir/usr/bin/astrbotctl"

    install -Dm644 "$srcdir/astrbot@.service" \
        "$pkgdir/usr/lib/systemd/system/astrbot@.service"

    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
