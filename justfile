alias p := push
alias pub := publish
alias c := clean

readme:
    bash readme.sh > readme.md

update-vcs-packages:
    bash update-vcs.sh

push FLAGS="-u" BRANSH="aurora":
    git push {{FLAGS}} github {{BRANSH}}
    git push {{FLAGS}} gitlab {{BRANSH}}
    git push {{FLAGS}} codeberg {{BRANSH}}
    git push {{FLAGS}} disroot {{BRANSH}}
    git push {{FLAGS}} tangled {{BRANSH}}
    git push {{FLAGS}} codefloe {{BRANSH}}

publish PKG:
    aurpublish {{PKG}}

upgrade PKG VERSION:
    #!/usr/bin/env bash
    set -euo pipefail
    pkg="{{PKG}}"
    ver="{{VERSION}}"
    for suffix in "" "-bin"; do
        dir="${pkg}${suffix}"
        [ -d "$dir" ] || continue
        echo "=== ${dir} -> ${ver} ==="
        sed -i "s/^pkgver=.*$/pkgver=${ver}/" "$dir/PKGBUILD"
        sed -i "s/^pkgrel=.*$/pkgrel=1/" "$dir/PKGBUILD"
        ./update-sums.sh "$dir/PKGBUILD"
        #(cd "$dir" && makepkg --printsrcinfo > .SRCINFO)
        (cd "$dir" && makepkg -sc)
        git add "$dir/PKGBUILD"
        git commit --allow-empty
    done
    just readme
    git add readme.md readme.sh
    git commit -m "docs(readme): update" || true
    for suffix in "" "-bin"; do
        dir="${pkg}${suffix}"
        [ -d "$dir" ] || continue
        just publish "$dir"
    done

clean:
    git clean -ffdx
