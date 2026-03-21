# Maintainer: lightjunction <lightjunction.me@gmail.com>

pkgname=astrbot-git
_pkgname=astrbot
pkgver=0.0.0.r1.gf9243a7
pkgrel=2
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

pkgver() {
    cd "$srcdir/$_pkgname"
    local _ver
    _ver=$(git describe --long --tags 2>/dev/null) && {
        echo "$_ver" | sed 's/\([^-]*-g\)/r\1/;s/-/./g' | sed 's/^v//g'
    } || echo "0.0.0.r$(git rev-list --count HEAD).g$(git rev-parse --short HEAD)"
}

prepare() {
    rm -rf "$srcdir/$_pkgname"

    # 重试机制，应对网络不稳定
    local _retries=3
    local _count=0
    while [ $_count -lt $_retries ]; do
        _count=$((_count + 1))
        echo ">>> 尝试克隆 ($_count/$_retries)..."
        if git clone --depth=1 -b dev https://github.com/AstrBotDevs/AstrBot.git "$srcdir/$_pkgname" 2>&1; then
            break
        fi
        echo ">>> 克隆失败，重试中..."
        sleep 5
        rm -rf "$srcdir/$_pkgname"
    done

    if [ ! -d "$srcdir/$_pkgname" ]; then
        echo "❌ 克隆失败，已放弃"
        return 1
    fi
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
