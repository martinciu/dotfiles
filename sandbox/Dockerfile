# syntax=docker/dockerfile:1
FROM debian:trixie-slim

ARG USER=dev
ARG UID=1000

# Non-root user with passwordless sudo (build-time convenience for apt; the
# runtime drops caps and adds no-new-privileges via the wrapper).
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl sudo \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -lm -u ${UID} -s /bin/bash ${USER} \
 && echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER} \
 && chmod 0440 /etc/sudoers.d/${USER}

USER ${USER}
ENV HOME=/home/${USER}
WORKDIR /home/${USER}

# --- base system (apt + locales). Changes rarely → early cached layer.
COPY --chown=${USER}:${USER} sandbox/install-linux.sh /home/${USER}/.sandbox/install-linux.sh
RUN bash /home/${USER}/.sandbox/install-linux.sh base

# --- tools via mise. Busts only when mise.toml changes.
# GITHUB_TOKEN passed as a build secret avoids rate-limiting on GH API calls
# (mise hits the releases API for every aqua: / github: backend tool).
COPY --chown=${USER}:${USER} sandbox/mise.toml /home/${USER}/.config/mise/config.toml
RUN --mount=type=secret,id=github_token,mode=0444 \
    GITHUB_TOKEN="$(cat /run/secrets/github_token 2>/dev/null || true)" \
    bash /home/${USER}/.sandbox/install-linux.sh mise

# --- nvim config + build-time plugin bake. Busts only when nvim config changes.
COPY --chown=${USER}:${USER} .config/nvim /home/${USER}/.config/nvim
RUN bash /home/${USER}/.sandbox/install-linux.sh nvim

# --- fish + worktrunk config last (cheapest to rebuild) + seed/shell wiring.
COPY --chown=${USER}:${USER} .config/fish /home/${USER}/.config/fish
COPY --chown=${USER}:${USER} .config/worktrunk/config.toml /home/${USER}/.config/worktrunk/config.toml
RUN bash /home/${USER}/.sandbox/install-linux.sh config

# --- theme assets (all variants) + Solarized floor. Cheap layer; busts only
# when a theme asset file changes. The active theme is applied at container
# entry by bin/sandbox (runtime), not frozen here — the floor is just the safe
# default for a raw `docker run` that bypasses the wrapper.
COPY --chown=${USER}:${USER} .config/themes /home/${USER}/.config/themes
COPY --chown=${USER}:${USER} .config/glow /home/${USER}/.config/glow
COPY --chown=${USER}:${USER} .config/lnav/configs/installed /home/${USER}/.config/lnav/configs/installed
COPY --chown=${USER}:${USER} .config/starship-*.toml /home/${USER}/.config/
RUN bash /home/${USER}/.sandbox/install-linux.sh theme solarized

# Persistent idle PID 1 so the container stays up for multiple `docker exec`
# shells; tini reaps zombies from whatever runs inside.
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["sleep", "infinity"]
