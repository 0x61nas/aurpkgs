#!/usr/bin/env bash
set -euo pipefail

pkgbuild="${1:-PKGBUILD}"
[ -f "$pkgbuild" ] || { echo "usage: $0 [path/to/PKGBUILD]" >&2; exit 1; }

cd "$(dirname "$(readlink -f "$pkgbuild")")"
pkgbuild="$(basename "$pkgbuild")"

source "$pkgbuild"

get_url()   { local s="$1"; if [[ "$s" == *::* ]]; then echo "${s#*::}"; else echo "$s"; fi; }
get_fn()    { local s="$1"; if [[ "$s" == *::* ]]; then echo "${s%%::*}"; else local u; u="$(get_url "$s")"; basename "$u"; fi; }
is_remote() { [[ "$1" == *://* ]]; }
is_vcs()    { [[ "$1" == git+* || "$1" == svn+* || "$1" == bzr+* || "$1" == hg+* ]]; }

fmt() {
    if [[ $# -eq 1 ]]; then
        echo "('$1')"
    else
        local out="(\\n"
        for s in "$@"; do out+="    '${s}'\\n"; done
        out+=")"
        printf '%s' "$out"
    fi
}

ALL_HASHES=(sha256 sha512 sha1 md5 b2)

existing_hashes() {
    local prefix="$1" result=()
    for h in "${ALL_HASHES[@]}"; do
        grep -q "^${h}sums${prefix}=" "$pkgbuild" 2>/dev/null && result+=("$h")
    done
    echo "${result[@]}"
}

replace_or_add() {
    local var="$1" val="$2"
    local start
    start="$(grep -n "^${var}=" "$pkgbuild" | head -1 | cut -d: -f1 || true)"
    if [[ -n "$start" ]]; then
        if sed -n "${start}p" "$pkgbuild" | grep -q ')$'; then
            sed -i "${start}c\\${var}=${val}" "$pkgbuild"
        else
            sed -i "${start},/^)/c\\${var}=${val}" "$pkgbuild"
        fi
    else
        sed -i "/^package()/i\\${var}=${val}" "$pkgbuild"
    fi
}

declare -A seen_fn

process_sources() {
    local src_var="$1" prefix="$2"
    [[ -z "${!src_var:+x}" ]] && return 0
    declare -n sources="$src_var"
    [[ ${#sources[@]} -eq 0 ]] && return 0

    local hashes=($(existing_hashes "$prefix"))
    [[ ${#hashes[@]} -eq 0 ]] && hashes=(sha256)

    local sums
    for h in "${hashes[@]}"; do
        sums=()
        for src in "${sources[@]}"; do
            local url fn
            url="$(get_url "$src")"
            fn="$(get_fn "$src")"
            if is_vcs "$url"; then
                sums+=('SKIP')
            elif is_remote "$url"; then
                local dl_fn="$fn"
                if [[ -n "$prefix" ]] && [[ -n "${seen_fn[$fn]:-}" ]]; then
                    dl_fn="${fn}-${prefix#_}"
                fi
                [ -f "$dl_fn" ] || curl -fSL -o "$dl_fn" "$url"
                sums+=($(${h}sum "$dl_fn" | awk '{print $1}'))
                seen_fn["$fn"]=1
            else
                sums+=($(${h}sum "$url" | awk '{print $1}'))
            fi
        done
        replace_or_add "${h}sums${prefix}" "$(fmt "${sums[@]}")"
    done
}

process_sources "source" ""

for a in "${arch[@]}"; do
    process_sources "source_$a" "_$a"
done

echo "updated checksums in $pkgbuild"
