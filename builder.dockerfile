FROM archlinux:base-devel@sha256:996c3a1d6b0d87b01242f6fcd8cfa3ad3eece1a67ab5c8f108e20af1d7b97bdd

RUN pacman -Syu --noconfirm \
    && pacman -S --needed --noconfirm git sudo \
    && useradd --create-home --uid 1000 --user-group ThaBuilder \
    && install -d -m 0750 /etc/sudoers.d \
    && echo 'ThaBuilder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ThaBuilder \
    && chmod 0440 /etc/sudoers.d/ThaBuilder \
    && visudo -cf /etc/sudoers

VOLUME ["/var/cache/pacman/pkg"]

WORKDIR /workspace

USER ThaBuilder

RUN git clone --depth=1 https://aur.archlinux.org/yay.git /home/ThaBuilder/yay \
    && cd /home/ThaBuilder/yay \
    && makepkg -si --noconfirm \
    && rm -rf /home/ThaBuilder/yay

ENTRYPOINT []
CMD ["/bin/bash"]
