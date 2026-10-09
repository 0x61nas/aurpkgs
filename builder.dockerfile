FROM archlinux:base-devel@sha256:996c3a1d6b0d87b01242f6fcd8cfa3ad3eece1a67ab5c8f108e20af1d7b97bdd

RUN useradd --create-home --uid 1000 --user-group ThaBuilder \
    && echo "ThaBuilder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ThaBuilder \
    && chmod 0440 /etc/sudoers.d/ThaBuilder

VOLUME ["/var/cache/pacman/pkg"]

RUN pacman -Syu --noconfirm

WORKDIR /workspace

USER ThaBuilder

ENTRYPOINT []
CMD ["/bin/bash"]
