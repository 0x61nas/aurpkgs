#!/usr/bin/env bash
set -euo pipefail

echo "# AUR Packages"
echo
echo "| Package | Description | Version |"
echo "|--------|-------------|---------|"

for dir in */; do
    case "$dir" in
        .git/|.github/) continue ;;
    esac

    [ -f "$dir/PKGBUILD" ] || continue

    unset pkgname pkgdesc pkgver pkgrel epoch
    source "$dir/PKGBUILD"

    if [[ -n "${epoch:-}" ]]; then
        ver="${epoch}:${pkgver}-${pkgrel}"
    else
        ver="${pkgver}-${pkgrel}"
    fi

    echo "| \`${pkgname}\` | ${pkgdesc} | ${ver} |"
done
