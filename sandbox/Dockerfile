# syntax=docker/dockerfile:1
FROM debian:trixie-slim

ARG USER=dev
ARG UID=1000

# Non-root user with passwordless sudo (build-time convenience for apt; the
# runtime drops caps and adds no-new-privileges via the wrapper).
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl sudo \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m -u ${UID} -s /bin/bash ${USER} \
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

# Persistent idle PID 1 so the container stays up for multiple `docker exec`
# shells; tini reaps zombies from whatever runs inside.
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["sleep", "infinity"]
