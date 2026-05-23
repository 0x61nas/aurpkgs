#!/usr/bin/env bash
set -euo pipefail

pkgbuild="${1:-PKGBUILD}"
[ -f "$pkgbuild" ] || { echo "usage: $0 [path/to/PKGBUILD]" >&2; exit 1; }

cd "$(dirname "$(readlink -f "$pkgbuild")")"
pkgbuild="$(basename "$pkgbuild")"

for v in pkgname pkgver pkgrel arch source sha256sums; do unset "$v" 2>/dev/null || true; done
for a in x86_64 aarch64 riscv64 i686 armv7h loong64 pentium4; do
    for v in source sha256sums; do unset "${v}_$a" 2>/dev/null || true; done
done

source "$pkgbuild"

get_url()   { local s="$1"; if [[ "$s" == *::* ]]; then echo "${s#*::}"; else echo "$s"; fi; }
get_fn()    { local s="$1"; if [[ "$s" == *::* ]]; then echo "${s%%::*}"; else local u; u="$(get_url "$s")"; basename "$u"; fi; }
is_remote() { [[ "$1" == *://* ]]; }

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

# replace_var <var> <value> <file>
# Replaces an existing var= assignment (potentially multi-line) with new value.
# Returns 0 on success, 1 if var not found.
replace_var() {
    local var="$1" val="$2" file="$3"
    local start end
    start="$(grep -n "^${var}=" "$file" | head -1 | cut -d: -f1)"
    [[ -z "$start" ]] && return 1

    if sed -n "${start}p" "$file" | grep -q ')$'; then
        sed -i "${start}c\\${var}=${val}" "$file"
    else
        end="$(tail -n +$((start + 1)) "$file" | grep -n ')$' | head -1 | cut -d: -f1)"
        if [[ -n "$end" ]]; then
            end=$((start + end))
            sed -i "${start},${end}c\\${var}=${val}" "$file"
        fi
    fi
    return 0
}

# ---- download & checksum ----

declare -A seen_fn

for src in "${source[@]}"; do
    url="$(get_url "$src")"
    fn="$(get_fn "$src")"
    if is_remote "$url"; then
        [ -f "$fn" ] || curl -sfSL -o "$fn" "$url"
        seen_fn["$fn"]=1
    fi
done

declare -A rename_for_sum

for a in "${arch[@]}"; do
    src_varname="source_$a"
    [[ -z "${!src_varname:+x}" ]] && continue
    declare -n src_arr="$src_varname"
    for src in "${src_arr[@]}"; do
        url="$(get_url "$src")"
        fn="$(get_fn "$src")"
        if is_remote "$url"; then
            if [[ -n "${seen_fn[$fn]:-}" ]]; then
                rename_for_sum["${a}_${fn}"]="${fn}-${a}"
            fi
            seen_fn["$fn"]=1
        fi
    done
done

# ---- update PKGBUILD ----

# replace / add sha256sums (common)
if [[ ${#source[@]} -gt 0 ]]; then
    sums=()
    for src in "${source[@]}"; do
        url="$(get_url "$src")"
        fn="$(get_fn "$src")"
        if is_remote "$url"; then
            sums+=($(sha256sum "$fn" | awk '{print $1}'))
        else
            sums+=($(sha256sum "$url" | awk '{print $1}'))
        fi
    done
    val="$(fmt "${sums[@]}")"
    if ! replace_var sha256sums "$val" "$pkgbuild"; then
        sed -i "/^package()/i\\sha256sums=${val}" "$pkgbuild"
    fi
fi

# replace / add per-arch sha256sums
for a in "${arch[@]}"; do
    src_varname="source_$a"
    sums_varname="sha256sums_$a"
    [[ -z "${!src_varname:+x}" ]] && continue
    declare -n src_arr="$src_varname"
    if [[ ${#src_arr[@]} -gt 0 ]]; then
        sums=()
        for src in "${src_arr[@]}"; do
            url="$(get_url "$src")"
            fn="$(get_fn "$src")"
            if is_remote "$url"; then
                use_fn="$fn"
                key="${a}_${fn}"
                [[ -n "${rename_for_sum[$key]:-}" ]] && use_fn="${rename_for_sum[$key]}"
                [ -f "$use_fn" ] || curl -sfSL -o "$use_fn" "$url"
                sums+=($(sha256sum "$use_fn" | awk '{print $1}'))
            else
                sums+=($(sha256sum "$url" | awk '{print $1}'))
            fi
        done
        val="$(fmt "${sums[@]}")"
        if ! replace_var "$sums_varname" "$val" "$pkgbuild"; then
            sed -i "/^package()/i\\${sums_varname}=${val}" "$pkgbuild"
        fi
    fi
done

echo "updated checksums in $pkgbuild"
