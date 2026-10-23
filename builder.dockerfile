FROM archlinux:base-devel@sha256:3cbf69d2d5958d6a294f3722c5668e6187c4df8e00fa27f72352f0bf83e495e1

RUN pacman -Syu --noconfirm \
    && pacman -Fy \
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
