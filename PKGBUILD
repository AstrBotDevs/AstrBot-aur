# Maintainer: lightjunction <lightjunction.me@gmail.com>

pkgname=astrbot-git
_pkgname=astrbot
pkgver=4.20.1.r55.g589776a
pkgrel=7
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
    "tmpl.conf"
)

sha256sums=('SKIP' 'SKIP' 'SKIP')

install=astrbot-git.install

prepare() {
    local _mirror="$srcdir/astrbot-git"

    if [ ! -d "$_mirror" ]; then
        git clone --bare --mirror https://github.com/AstrBotDevs/AstrBot.git "$_mirror"
    fi

    git -C "$_mirror" fetch --prune origin
    rm -rf "$srcdir/$_pkgname"
    git clone --depth=500 "file://$_mirror" "$srcdir/$_pkgname"
}

pkgver() {
    cd "$srcdir/$_pkgname"
    local _ver
    _ver=$(git describe --long --tags 2>/dev/null) && {
        echo "$_ver" | sed 's/\([^-]*-g\)/r\1/;s/-/./g' | sed 's/^v//g'
    } || echo "0.0.0.r$(git rev-list --count HEAD).g$(git rev-parse --short HEAD)"
}

package() {
    cd "$srcdir/$_pkgname"

    local _appdir="/opt/$_pkgname"

    install -d "$pkgdir$_appdir"
    cp -r astrbot scripts pyproject.toml README.md LICENSE "$pkgdir$_appdir/"

    install -Dm644 "$srcdir/tmpl.conf" "$pkgdir/etc/astrbot/tmpl.conf"

    install -Dm755 "$srcdir/astrbotctl" \
        "$pkgdir/usr/bin/astrbotctl"

    install -Dm644 "$srcdir/astrbot@.service" \
        "$pkgdir/usr/lib/systemd/system/astrbot@.service"

    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
