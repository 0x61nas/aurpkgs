# Maintainer: Anas Elgarhy <anas.elgarhy.dev@gmail.com>
pkgname=typepper-git
_pkgname=typepper
pkgver=0.2.0.r2.g49a6d25
pkgrel=1
pkgdesc='A spicy little typing game for your terminal.'
arch=(
    'x86_64'
    'aarch64'
    'riscv64'
)
url='https://github.com/leodiegues/typepper'
license=('GPL-3.0-or-later')
makedepends=(
    'cargo'
    'git'
)
options=(
    !lto
    !debug
)
provides=('typepper')
conflicts=('typepper' 'typepper-bin')
source=(
    "$_pkgname-main::git+$url.git#branch=main"
    'typepper.desktop'
)
sha256sums=(
    'SKIP'
    '4883d7befe7104f709a566b75659b335c9ba4d1edcd139eccf87bb92ec0917ae'
)

pkgver() {
    cd "${_pkgname}-main"
    git describe --long --abbrev=7 --tags | sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g'
}

prepare() {
    cd "${_pkgname}-main"
    cargo fetch --locked --target "$CARCH-unknown-linux-gnu"
}

build() {
    cd "${_pkgname}-main"
    export RUSTUP_TOOLCHAIN=stable
    export CARGO_TARGET_DIR=target
    cargo build --frozen --release
}

package() {
    cd "${_pkgname}-main"

    install -Dm0755 target/release/typepper "$pkgdir/usr/bin/typepper"
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
    install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"

    install -Dm644 ../typepper.desktop "$pkgdir/usr/share/applications/typepper.desktop"

    install -Dm644 assets/logo/icon-128.png "$pkgdir/usr/share/icons/hicolor/128x128/apps/typepper.png"
    install -Dm644 assets/logo/icon-256.png "$pkgdir/usr/share/icons/hicolor/256x256/apps/typepper.png"
    install -Dm644 assets/logo/icon-512.png "$pkgdir/usr/share/icons/hicolor/512x512/apps/typepper.png"
    install -Dm644 assets/logo/icon-1024.png "$pkgdir/usr/share/icons/hicolor/1024x1024/apps/typepper.png"
}

# vim: ts=4 sw=4 et:
