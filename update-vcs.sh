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
    unset pkgname pkgver pkgrel epoch _publish
    source PKGBUILD

    if ! git diff --quiet HEAD -- PKGBUILD; then
        git add PKGBUILD
        git commit -m "feat: update ${pkgname} to ${pkgver}"
    else
        echo "$pkgname is aready at the latest refrence"
        popd >/dev/null
        continue
    fi

    popd >/dev/null
    echo Exit: $dir

    ./x readme
    git add readme.md
    git commit -m "docs: update tha readme"

    if [[ -n "$_publish" && "$_publish" != 'false'  ]]; then
        ./x publish "$pkgname"
    fi
done
