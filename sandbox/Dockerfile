# Command sandbox for Hermes (terminal.backend: ssh). Holds no Hermes secrets:
# the agent's shell, file and code tools run here instead of in hermes-agent.
# Pinned by digest; Dependabot proposes bumps.
FROM debian:trixie-slim@sha256:f6b08b09a05725f9431502d3b5714f5c4576e82c1a84fa1debe0c24a7e0c3ec4

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server ca-certificates curl git jq ripgrep procps less \
        python3 python-is-python3 python3-venv python3-pip build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/ssh/ssh_host_* \
    && useradd --uid 1000 --create-home --home-dir /data/home --shell /bin/bash hermes \
    && usermod -p '*' hermes \
    && mkdir -p /run/sshd

COPY sshd_config /etc/ssh/sshd_config
COPY --chmod=0755 entrypoint.sh /usr/local/bin/sandbox-entrypoint

# /data is the Railway volume: home directory (agent files) and SSH host keys.
EXPOSE 2222
ENTRYPOINT ["/usr/local/bin/sandbox-entrypoint"]
