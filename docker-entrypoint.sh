#!/bin/sh
# Railway wrapper for the official Hermes image. Maps ADMIN_* to the dashboard
# auth variables, handles the one-time move from the old /data layout to the
# upstream /opt/data layout, then hands off to the upstream entrypoint.
set -eu

log() { echo "[railway] $*"; }

DATA=/opt/data
OLD="$DATA/.hermes"
MARKER="$DATA/.layout-v2"

use_home() {
    export HERMES_HOME="$1"
    export HERMES_WRITE_SAFE_ROOT="$1"
    export HERMES_LAZY_INSTALL_TARGET="$1/lazy-packages"
    export HERMES_WEBUI_STATE_DIR="$1/webui"
}

migrate() {
    log "migrating $OLD -> $DATA"
    need_kb=$(( $(du -sk "$OLD" | cut -f1) + 102400 ))
    free_kb=$(df -Pk "$DATA" | awk 'NR==2 {print $4}')
    if [ "$free_kb" -lt "$need_kb" ]; then
        log "not enough space for a backup (${free_kb}KB free, ${need_kb}KB needed); skipping migration"
        return 1
    fi
    for p in "$OLD"/* "$OLD"/.[!.]* "$OLD"/..?*; do
        [ -e "$p" ] || [ -L "$p" ] || continue
        name=${p##*/}
        [ -e "$DATA/$name" ] || [ -L "$DATA/$name" ] || continue
        # workspace exists in both (agent's and WebUI's): merge if no name overlaps.
        if [ "$name" = workspace ] && [ -d "$p" ] && [ ! -L "$p" ] && [ -d "$DATA/workspace" ] && [ ! -L "$DATA/workspace" ]; then
            overlap=$(cd "$p" && for f in * .[!.]* ..?*; do [ -e "$f" ] || [ -L "$f" ] || continue; [ -e "$DATA/workspace/$f" ] || [ -L "$DATA/workspace/$f" ] && echo "$f"; done)
            if [ -z "$overlap" ]; then
                continue
            fi
            log "workspace merge blocked; both contain: $(echo "$overlap" | tr '\n' ' ')"
        else
            log "name clash: $DATA/$name already exists"
        fi
        log "skipping migration"
        return 1
    done
    before=$(find "$OLD" -mindepth 1 | wc -l)
    backup="$DATA/.migration-backup-$(date -u +%Y%m%dT%H%M%SZ).tar"
    if ! tar -cf "$backup" -C "$DATA" .hermes; then
        rm -f "$backup"
        log "backup failed; skipping migration"
        return 1
    fi
    log "backup written: $backup ($(du -sh "$backup" | cut -f1))"
    moved=""
    restore() {
        log "move failed at $1; restoring"
        for n in $moved; do mv "$DATA/$n" "$OLD/$n" || log "RESTORE FAILED for $n (backup: $backup)"; done
    }
    for p in "$OLD"/* "$OLD"/.[!.]* "$OLD"/..?*; do
        [ -e "$p" ] || [ -L "$p" ] || continue
        name=${p##*/}
        if [ "$name" = workspace ] && [ -d "$DATA/workspace" ]; then
            for c in "$p"/* "$p"/.[!.]* "$p"/..?*; do
                [ -e "$c" ] || [ -L "$c" ] || continue
                if ! mv "$c" "$DATA/workspace/"; then restore "workspace/${c##*/}"; return 1; fi
                moved="$moved workspace/${c##*/}"
            done
            rmdir "$p"
            continue
        fi
        if ! mv "$p" "$DATA/$name"; then restore "$name"; return 1; fi
        moved="$moved $name"
    done
    rmdir "$OLD"
    date -u +%Y-%m-%dT%H:%M:%SZ > "$MARKER"
    after=$(find "$DATA" -mindepth 1 -not -path "$DATA/workspace*" -not -path "$DATA/lost+found*" \
        -not -name '.migration-backup-*' -not -name .layout-v2 | wc -l)
    log "migration done: $before entries in .hermes before, $after at top level now"
}

if [ -d /data/.hermes ] && [ ! -L /data/.hermes ]; then
    # Volume still mounted at /data (old layout). Run as before.
    log "volume at /data (old layout); move the mount to /opt/data to finish upgrading"
    use_home /data/.hermes
    export HERMES_WEBUI_DEFAULT_WORKSPACE=/data/workspace
elif [ -d "$OLD" ] && [ ! -L "$OLD" ]; then
    if [ -e "$MARKER" ] || ! migrate; then
        log "running from $OLD (migration not completed)"
        use_home "$OLD"
    fi
elif [ -e "$MARKER" ]; then
    log "layout v2 (migrated $(cat "$MARKER"))"
fi

if [ "${HERMES_MIGRATION_CLEANUP:-}" = 1 ] && [ -e "$MARKER" ] && [ ! -e "$OLD" ]; then
    for f in "$DATA"/.migration-backup-*.tar; do
        [ -e "$f" ] || continue
        rm -f "$f" && log "deleted $f"
    done
fi

mkdir -p "$DATA/workspace"

dashboard_username="${HERMES_DASHBOARD_BASIC_AUTH_USERNAME:-${ADMIN_USERNAME:-admin}}"
dashboard_password="${HERMES_DASHBOARD_BASIC_AUTH_PASSWORD:-${ADMIN_PASSWORD:-}}"

if [ -z "$dashboard_password" ]; then
    echo "ADMIN_PASSWORD is not set. Set it in Railway variables." >&2
    exit 1
fi

# Fallback only: set HERMES_DASHBOARD_BASIC_AUTH_SECRET to a random value.
dashboard_secret="${HERMES_DASHBOARD_BASIC_AUTH_SECRET:-}"
if [ -z "$dashboard_secret" ]; then
    dashboard_secret="$(
        ADMIN_PASSWORD="$dashboard_password" python -c \
            'import base64, hashlib, os; print(base64.b64encode(hashlib.sha256(("hermes-dashboard-session:" + os.environ["ADMIN_PASSWORD"]).encode()).digest()).decode())'
    )"
fi

export HERMES_DASHBOARD_PORT="${HERMES_DASHBOARD_PORT:-${PORT:-8080}}"
export HERMES_DASHBOARD_BASIC_AUTH_USERNAME="$dashboard_username"
export HERMES_DASHBOARD_BASIC_AUTH_PASSWORD="$dashboard_password"
export HERMES_DASHBOARD_BASIC_AUTH_SECRET="$dashboard_secret"

# WebUI login defaults to the dashboard password.
export HERMES_WEBUI_PASSWORD="${HERMES_WEBUI_PASSWORD:-$dashboard_password}"

# Key for the SSH command sandbox (terminal.backend: ssh). Kept off the volume so
# it is never among the files Hermes syncs into the sandbox.
if [ -n "${HERMES_SANDBOX_SSH_KEY:-}" ]; then
    key_dir=/run/hermes-sandbox
    mkdir -p "$key_dir"
    printf '%s\n' "$HERMES_SANDBOX_SSH_KEY" > "$key_dir/id_ed25519"
    chown -R hermes:hermes "$key_dir"
    chmod 700 "$key_dir"
    chmod 600 "$key_dir/id_ed25519"
    export TERMINAL_SSH_KEY="${TERMINAL_SSH_KEY:-$key_dir/id_ed25519}"
    unset HERMES_SANDBOX_SSH_KEY
fi

exec /opt/hermes/docker/entrypoint-dispatch.sh "$@"
