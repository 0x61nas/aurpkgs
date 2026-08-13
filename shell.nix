{ pkgs ? import <nixpkgs> {} }:

# Build environment that lets unprivileged users run `makepkg -sc` against a
# real (but fake-in-place) Arch Linux filesystem.
#
# Instead of pointing pacman at a disconnected "fake root" while building with
# Nix tools, we:
#   1. bootstrap a proper Arch rootfs (`base` + `base-devel`) into
#      $AURPKGS_STATE/archroot with the host `pacman -r`,
#   2. chroot into that rootfs with proot (no privileges required),
#   3. run `makepkg` there with `PACMAN_AUTH=(fakeroot)` so `-s` can install
#      missing dependencies into the very same filesystem that is built in.
#
# Everything the build needs (gcc, make, patch, X11 headers, ...) comes from
# that one coherent rootfs, so there are no more mismatched environments.

let
  hostPacman  = "${pkgs.pacman}/bin/pacman";
  hostFakeroot = "${pkgs.fakeroot}/bin/fakeroot";

  # Idempotent local fixes that keep the rootfs usable. Runs on every entry so
  # that rootfs created by an older/partial bootstrap heals itself.
  repair = pkgs.writeShellScriptBin "aurpkgs-repair" ''
    set -euo pipefail

    STATE="$AURPKGS_STATE"
    ARCHROOT="$STATE/archroot"
    mkdir -p "$ARCHROOT/var/lib/pacman" "$ARCHROOT/etc/pacman.d"

    # Config used *inside* the chroot.
    cat > "$ARCHROOT/etc/pacman.conf" <<'EOF'
[options]
RootDir = /
DBPath = /var/lib/pacman
CacheDir = /var/cache/pacman/pkg
LogFile = /var/log/pacman.log
HoldPkg = pacman glibc
Architecture = auto
SigLevel = Never
LocalFileSigLevel = Never
ParallelDownloads = 5
Color

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF

    cat > "$ARCHROOT/etc/pacman.d/mirrorlist" <<'MIRROR'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
MIRROR

    # No real root here: let makepkg run pacman through fakeroot so `-s`
    # can install missing deps into the chroot.
    if ! grep -q '^PACMAN_AUTH' "$ARCHROOT/etc/makepkg.conf"; then
      printf '\n# installed by shell.nix\nPACMAN_AUTH=(fakeroot)\n' >> "$ARCHROOT/etc/makepkg.conf"
    fi
    if ! grep -q '^PACMAN_OPTS' "$ARCHROOT/etc/makepkg.conf"; then
      printf 'PACMAN_OPTS=(--noconfirm)\n' >> "$ARCHROOT/etc/makepkg.conf"
    fi

    # DNS inside the chroot.
    cp -L /etc/resolv.conf "$ARCHROOT/etc/resolv.conf" 2>/dev/null || true

    # ca-certificates' post-install hook chroot()-fails during the host-side
    # install above, so its bundle is never extracted. Build it inside proot
    # where chroot() is faked and succeeds.
    if [[ ! -f "$ARCHROOT/etc/ca-certificates/extracted/tls-ca-bundle.pem" ]]; then
      echo "==> Building CA certificate store..."
      # proot forwards the host's PATH, so give it Arch's paths for the tools
      # update-ca-trust shells out to (mkdir, openssl, ...).
      env PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/bin" \
        ${pkgs.proot}/bin/proot -r "$ARCHROOT" -b /proc -b /dev -b /sys -w / /usr/bin/update-ca-trust
    fi

    # The host's locale/TMPDIR don't exist inside the chroot; fix both.
    cat > "$ARCHROOT/etc/profile.d/aurpkgs.sh" <<'EOF'
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
unset TMPDIR
EOF
  '';

  # One-time bootstrap of the Arch rootfs, driven by the host's pacman.
  bootstrap = pkgs.writeShellScriptBin "aurpkgs-bootstrap" ''
    set -euo pipefail

    STATE="$AURPKGS_STATE"
    ARCHROOT="$STATE/archroot"
    CACHE="$STATE/cache"
    mkdir -p "$ARCHROOT/var/lib/pacman" "$CACHE"

    cat > "$STATE/mirrorlist" <<'MIRROR'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
MIRROR

    cat > "$STATE/pacman-bootstrap.conf" <<EOF
[options]
RootDir = $ARCHROOT
DBPath = $ARCHROOT/var/lib/pacman
CacheDir = $CACHE
LogFile = $STATE/pacman.log
HoldPkg = pacman glibc
Architecture = auto
SigLevel = Never
LocalFileSigLevel = Never
ParallelDownloads = 5
Color

[core]
Include = $STATE/mirrorlist

[extra]
Include = $STATE/mirrorlist

[multilib]
Include = $STATE/mirrorlist
EOF

    echo "==> Fetching pacman databases..."
    ${hostFakeroot} ${hostPacman} --config "$STATE/pacman-bootstrap.conf" -Sy --noconfirm

    echo "==> Installing base + base-devel into $ARCHROOT (first run only)..."
    ${hostFakeroot} ${hostPacman} --config "$STATE/pacman-bootstrap.conf" \
      -S --needed --noconfirm base base-devel git curl

    ${repair}/bin/aurpkgs-repair
  '';

  # Enter the Arch rootfs with proot (fake in-place chroot, no privileges).
  aurpkgs = pkgs.writeShellScriptBin "aurpkgs" ''
    set -euo pipefail

    STATE="''${AURPKGS_STATE:-''${XDG_CACHE_HOME:-$HOME/.cache}/aurpkgs}"
    export AURPKGS_STATE="$STATE"
    ARCHROOT="$STATE/archroot"

    if [[ ! -x "$ARCHROOT/usr/bin/bash" ]]; then
      ${bootstrap}/bin/aurpkgs-bootstrap
    else
      # heal rootfs created by older/partial bootstraps
      ${repair}/bin/aurpkgs-repair
    fi

    # Expose the enclosing repo (or the current dir) so the build can write there.
    BINDROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$BINDROOT" ]] || BINDROOT="$PWD"

    proot() { ${pkgs.proot}/bin/proot "$@"; }

    if [[ $# -eq 0 ]]; then
      exec proot -r "$ARCHROOT" \
        -b /proc -b /dev -b /sys -b /etc/resolv.conf -b "$BINDROOT" -w "$PWD" \
        /bin/bash --login
    fi

    exec proot -r "$ARCHROOT" \
      -b /proc -b /dev -b /sys -b /etc/resolv.conf -b "$BINDROOT" -w "$PWD" \
      /bin/bash --login -c 'exec "$@"' _ "$@"
  '';

  # Proxy binaries so `makepkg`/`pacman` transparently run inside the chroot.
  makepkgShim = pkgs.writeShellScriptBin "makepkg" ''
    exec ${aurpkgs}/bin/aurpkgs makepkg "$@"
  '';

  pacmanShim = pkgs.writeShellScriptBin "pacman" ''
    exec ${aurpkgs}/bin/aurpkgs pacman "$@"
  '';
in
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    proot
    pacman
    fakeroot
    coreutils
    gnugrep
    gnused
    gawk
  ];

  shellHook = ''
    export AURPKGS_STATE=''${AURPKGS_STATE:-''${XDG_CACHE_HOME:-$HOME/.cache}/aurpkgs}
    # shims must shadow the host pacman/makepkg on PATH
    export PATH="${makepkgShim}/bin:${pacmanShim}/bin:${aurpkgs}/bin:${bootstrap}/bin:$PATH"
  '';
}
