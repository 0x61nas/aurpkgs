#!/usr/bin/env bash

set -euo pipefail

REPO_NAME='aurpkgs'
declare -A GIT_REMOTES=(
    [github]="git@github.com:0x61nas/${REPO_NAME}.git"
    [gitlab]="git@gitlab.com:anelgarhy/${REPO_NAME}.git"
    [codeberg]="ssh://git@codeberg.org/0x61nas/${REPO_NAME}.git"
    [disroot]="ssh://git@git.disroot.org/anas/${REPO_NAME}.git"
    [tangled]="git@tangled.org:anas.tngl.sh/${REPO_NAME}"
    [gitgud]="git@ssh.gitgud.io:anelgarhy/${REPO_NAME}.git"
    [codefloe]="ssh://git@codefloe.com/anas/${REPO_NAME}.git"
)

ok()   { echo -e "  $1"; }
fail() { echo -e "  $1"; }
info() { echo -e "  $1"; }
warn() { echo -e "  $1"; }

usage() {
    cat <<EOF
Usage: x <command> [args]

Commands:
  readme                    Generate readme.md from package metadata
  update-vcs                Update VCS (-git) packages
  publish <package>         Publish a package via aurpublish.bash
  upgrade <pkg> <ver>       Upgrade a package to a new version
  push [flags] [branch]     Push branch to all remotes (default: -u aurora)
  push-tags                 Push tags to all remotes
  clean                     Remove untracked files and directories
  setup-remotes             Register all git remotes
  print-remotes             Display configured git remotes
  help                      Show this help message
EOF
    exit 0
}

error() {
    local arg="${1-}"
    echo -e "Error: unknown command '${arg}'" >&2
    echo "Run 'x help' for usage" >&2
    exit 1
}

print-remotes() {
    for remote in "${!GIT_REMOTES[@]}"; do
        echo "  $remote -> ${GIT_REMOTES[$remote]}"
    done
}

setup-remotes() {
    for remote in "${!GIT_REMOTES[@]}"; do
        if git remote add "$remote" "${GIT_REMOTES[$remote]}" 2>/dev/null; then
            ok "added remote $remote"
        else
            warn "remote $remote already exists"
        fi
    done
}

push() {
    local flags=()
    local branch="aurora"

    for arg in "$@"; do
        if [[ "$arg" == -* ]]; then
            flags+=("$arg")
        else
            branch="$arg"
        fi
    done

    [[ ${#flags[@]} -eq 0 ]] && flags=("-u")

    local flag_str="${flags[*]}"
    echo -e "Pushing to all remotes"
    echo -e "  Branch: $branch  Flags: ${flag_str:-(none)}"
    echo

    local ok=true
    for remote in "${!GIT_REMOTES[@]}"; do
        info "pushing to $remote..."
        if git push "${flags[@]}" "$remote" "$branch"; then
            ok "pushed to $remote"
        else
            fail "failed to push to $remote"
            ok=false
        fi
    done
    echo
    if $ok; then
        ok "all pushes succeeded"
    else
        fail "some pushes failed"
        return 1
    fi
}

push-tags() {
    push "$@"
    echo
    echo -e "Pushing tags to all remotes"
    echo
    local ok=true
    for remote in "${!GIT_REMOTES[@]}"; do
        info "pushing tags to $remote..."
        if git push --tags "$remote"; then
            ok "tags pushed to $remote"
        else
            fail "failed to push tags to $remote"
            ok=false
        fi
    done
    echo
    if $ok; then
        ok "all tag pushes succeeded"
    else
        fail "some tag pushes failed"
        return 1
    fi
}

publish() {
    local pkg="${1-}"
    if [[ -z "$pkg" ]]; then
        echo -e "Error: package name required" >&2
        echo "Usage: x publish <package>" >&2
        exit 1
    fi
    echo -e "Publishing $pkg"
    bash ./aurpublish.bash -s  "$pkg"
    ok "published $pkg"
}

readme() {
    echo -e "Generating readme.md"
    bash readme.sh > readme.md
    ok "readme.md generated"
}

update-vcs() {
    echo -e "Updating VCS packages"
    bash update-vcs.sh
}

upgrade() {
    local pkg="${1-}"
    local ver="${2-}"
    local skip_build="${3-}"
    if [[ -z "$pkg" || -z "$ver" ]]; then
        echo -e "Error: usage: x upgrade <package> <version> [--skip-build]" >&2
        exit 1
    fi

    if [[ -n "$skip_build" && "$skip_build" != "--skip-build" ]]; then
        echo -e "Error: unknown option \`$skip_build\`"
        exit 1
    fi

    echo -e "Upgrading $pkg to $ver"
    echo

    for suffix in "" "-bin"; do
        dir="${pkg}${suffix}"
        [[ -d "$dir" ]] || continue

        unset _publish
        source "$dir/PKGBUILD"
        if [[ "${_publish-false}" == "false" ]]; then
            warn "skipping $dir (publish disabled)"
            continue
        fi

        info "processing $dir..."

        sed -i "s/^pkgver=.*$/pkgver=${ver}/" "$dir/PKGBUILD"
        sed -i "s/^pkgrel=.*$/pkgrel=1/" "$dir/PKGBUILD"
        ./update-sums.sh "$dir/PKGBUILD"
        if [[ -z "$skip_build" ]]; then
            (cd "$dir" && makepkg -sc) || exit 1
        fi
        (cd "$dir" && makepkg --printsrcinfo > ".SRCINFO")
        git add "$dir/PKGBUILD" "$dir/.SRCINFO"
        git commit --allow-empty -m "upgrade($dir): ${ver}"
        ok "upgraded $dir to ${ver}"
    done

    echo
    readme
    git add readme.md readme.sh
    git commit -m "docs(readme): update" || true

    for suffix in "" "-bin"; do
        dir="${pkg}${suffix}"
        [[ -d "$dir" ]] || continue

        unset _publish
        source "$dir/PKGBUILD"
        if [[ "${_publish-false}" == "false" ]]; then
            continue
        fi
        publish "$dir"
    done

    echo
    ok "upgrade complete"
}

pkg-version() {
    local pkg="${1-}"
    source "$pkg/PKGBUILD"
    echo "Current $pkg version: '$pkgver'"
}

clean() {
    echo -e "Cleaning untracked files"
    git clean -ffdx
    ok "clean complete"
}

arg="${1-}"
[[ -z "$arg" ]] && usage
shift

case $arg in
    help|h|--help|-h) usage ;;
    print-remotes|pr) print-remotes ;;
    setup-remotes|sr) setup-remotes ;;
    push|p) push "$@" ;;
    push-tags|pusht|pt) push-tags "$@" ;;
    publish|pub) publish "${1-}" ;;
    readme|r) readme ;;
    update-vcs|update-vcs-packages|uv) update-vcs ;;
    upgrade|up) upgrade "$@" ;;
    version|ver|pkgver) pkg-version "${1-}" ;;
    clean|c) clean ;;
    *) error "$arg" ;;
esac
