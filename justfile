REPO_NAME := 'aurpkgs'

alias p := push
alias pub := publish
alias c := clean

readme:
    bash readme.sh > readme.md

update-vcs-packages:
    bash update-vcs.sh

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

setup-remotes:
    git remote add github git@github.com:0x61nas/{{REPO_NAME}}.git
    git remote add gitlab git@gitlab.com:anelgarhy/{{REPO_NAME}}.git
    git remote add codeberg ssh://git@codeberg.org/0x61nas/{{REPO_NAME}}.git
    git remote add disroot ssh://git@git.disroot.org/anas/{{REPO_NAME}}.git
    git remote add tangled git@tangled.org:anas.tngl.sh/{{REPO_NAME}}
    git remote add gitgud git@ssh.gitgud.io:anelgarhy/{{REPO_NAME}}.git
    git remote add codefloe ssh://git@codefloe.com/anas/{{REPO_NAME}}.git

# Push the code to all remotes
push FLAGS="-u" BRANSH="aurora":
    git push {{FLAGS}} github {{BRANSH}}
    git push {{FLAGS}} gitlab {{BRANSH}}
    git push {{FLAGS}} codeberg {{BRANSH}}
    git push {{FLAGS}} disroot {{BRANSH}}
    git push {{FLAGS}} tangled {{BRANSH}}
    git push {{FLAGS}} codefloe {{BRANSH}}
    git push {{FLAGS}} gitgud {{BRANSH}}

# Push the git tags to all remotes
pusht: push
    git push --tags github
    git push --tags gitlab
    git push --tags codeberg
    git push --tags disroot
    git push --tags tangled
    git push --tags codefloe
    git push --tags gitgud

clean:
    git clean -ffdx
