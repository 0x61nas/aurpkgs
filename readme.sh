#!/usr/bin/env bash

set -euo pipefail

echo "## Anas's AUR Packages"
echo
echo "| Package | Description | Version | Arch |"
echo "|---------|-------------|---------|------|"

for dir in */; do
    case "$dir" in
        .git/|.github/) continue ;;
    esac

    [ -f "$dir/PKGBUILD" ] || continue

    unset pkgname pkgdesc pkgver pkgrel epoch arch
    source "$dir/PKGBUILD"

    if [[ -n "${epoch:-}" ]]; then
        ver="${epoch}:${pkgver}-${pkgrel}"
    else
        ver="${pkgver}-${pkgrel}"
    fi

    arch_str=$(IFS=','; echo "${arch[*]}")

    echo "| \`${pkgname}\` | ${pkgdesc} | ${ver} | ${arch_str} |"
done

echo ""
