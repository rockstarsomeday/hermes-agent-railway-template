# Hermes Agent on Railway

Thin wrapper around the official `nousresearch/hermes-agent` image. No app code here.

- `Dockerfile` — upstream image + Hermes WebUI (pinned commit) as an s6 service; old `/data` symlinks
- `docker-entrypoint.sh` — maps `ADMIN_*` to dashboard auth, one-time `/data/.hermes` → `/opt/data` migration, then execs upstream `entrypoint-dispatch.sh`
- `s6-rc.d/webui/` — WebUI run/finish scripts (port 8787)
- `railway.toml` — start command, health check

## Rules

- Keep upstream defaults (`HERMES_HOME=/opt/data`, volume at `/opt/data`). Upstream hardcodes `HOME=/opt/data`; don't move data elsewhere.
- Pin versions (image tag, WebUI commit). Never `latest`.
- Any push to `main` redeploys on Railway.
- Never print or commit secrets (`ADMIN_PASSWORD`, API keys, `/opt/data/.env`).
