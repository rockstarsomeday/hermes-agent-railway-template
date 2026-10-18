#!/bin/sh
# Prepares the volume and the authorized key, then runs sshd in the foreground.
set -eu

if [ -z "${SANDBOX_AUTHORIZED_KEY:-}" ]; then
    echo "SANDBOX_AUTHORIZED_KEY is not set. Set it in Railway variables." >&2
    exit 1
fi

# Host key lives on the volume so Hermes's known_hosts entry survives redeploys.
mkdir -p /data/ssh /data/home/workspace
[ -f /data/ssh/ssh_host_ed25519_key ] || ssh-keygen -q -t ed25519 -N '' -f /data/ssh/ssh_host_ed25519_key
chmod 700 /data/ssh
chown hermes:hermes /data/home /data/home/workspace
chmod 700 /data/home

# Root-owned so the sandboxed user can't change who may log in.
mkdir -p /etc/ssh/authorized_keys
printf '%s\n' "$SANDBOX_AUTHORIZED_KEY" > /etc/ssh/authorized_keys/hermes
chmod 644 /etc/ssh/authorized_keys/hermes
# Keep the key out of the sandbox user's environment.
unset SANDBOX_AUTHORIZED_KEY

exec /usr/sbin/sshd -D -e
