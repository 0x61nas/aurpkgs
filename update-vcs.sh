#!/usr/bin/env bash

set -uo pipefail

echo starting...

for dir in *-git; do
    case "$dir" in
        .git/|.github/) continue ;;
    esac

    [ -f "$dir/PKGBUILD" ] || continue

    echo Enter: $dir
    pushd "$dir" >/dev/null

    makepkg --nobuild --nodeps --noprepare

    unset pkgname pkgver pkgrel epoch
    source PKGBUILD

    oldver="$pkgver"

    if declare -f pkgver >/dev/null; then
        newver="$(pkgver)"
    else
        popd >/dev/null || continue
        continue
    fi

    if [[ -n "$newver" && "$newver" != "$oldver" ]]; then
        sed -i "s/^pkgver=.*/pkgver=${newver}/" PKGBUILD
        sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD

        git add PKGBUILD
        git commit -m "feat: update ${pkgname} to ${newver}"
    else
        echo "$pkgname is aready at the latest refrence"
        popd >/dev/null
        continue
    fi

    popd >/dev/null
    echo Exit: $dir

    just readme
    git add readme.md
    git commit -m "docs: update tha readme"

    just publish "$pkgname"
done
