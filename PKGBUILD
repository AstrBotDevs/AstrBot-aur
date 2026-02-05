# Maintainer: lightjunction <lightjunction.me@gmail.com>
pkgname=astrbot-git
_pkgname=astrbot
pkgver=4.14.4.r2.g912e40e7
pkgrel=1
pkgdesc="Agentic IM Chatbot infrastructure that integrates lots of IM platforms, LLMs, plugins and AI features."
arch=('any')
url="https://github.com/AstrBotDevs/AstrBot"
license=('AGPL-3.0-only')
depends=('python')
makedepends=('git' 'python-build' 'python-installer' 'python-hatchling')
provides=("${_pkgname}")
conflicts=("${_pkgname}")
source=("${pkgname}::git+${url}.git")
sha256sums=('SKIP')

pkgver() {
    cd "$pkgname"
    # 例如：0.1.0.r10.g1234567
    git describe --long --tags | sed 's/\([^-]*-g\)/r\1/;s/-/./g' | sed 's/^v//g'
}

build() {
    cd "$pkgname"
    python -m build --wheel --no-isolation
}

package() {
    cd "$pkgname"
    # 将编译好的 wheel 安装到 $pkgdir 目录下
    python -m installer --destdir="$pkgdir" dist/*.whl

    # 安装许可证
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
