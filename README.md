# Hermes Agent on Railway

Runs the official [Hermes Agent](https://github.com/NousResearch/hermes-agent) image on Railway, plus [Hermes WebUI](https://github.com/nesquena/hermes-webui) in the same container. Originally ejected from the community Railway template; now kept close to upstream.

## Layout

| What | Where |
|---|---|
| Volume mount | `/opt/data` (upstream default `HERMES_HOME`) |
| Hermes data (config, sessions, memory, skills) | `/opt/data` |
| Agent home and working folder | `/opt/data` |
| WebUI workspace / state | `/opt/data/workspace`, `/opt/data/webui` |
| Dashboard | port `8080` (`PORT`) |
| WebUI | port `8787` |

Everything under `/opt/data` survives redeploys. Old `/data/...` paths are symlinked to the new layout.

## Railway settings

| Setting | Value |
|---|---|
| Start command | `/usr/local/bin/hermes-railway-entrypoint gateway run` (from `railway.toml`) |
| Volume mount | `/opt/data` |
| Health check | `/api/status` |
| Replicas | `1` |
| Public domains | none; reached only through the Cloudflare tunnel |

### Variables

| Variable | Notes |
|---|---|
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | Dashboard login; WebUI uses the same password. Required. |
| `HERMES_DASHBOARD_BASIC_AUTH_SECRET` | Random session-signing secret (32+ bytes). Rotating it logs everyone out. |
| `HERMES_WEBUI_PASSWORD` | Optional separate WebUI password |
| `HERMES_WEBUI=0` | Disable WebUI |

### Hostnames (Cloudflare tunnel, one Access app)

| Hostname | Service |
|---|---|
| `hermes.chrisvis.com` | WebUI, `hermes-agent.railway.internal:8787` (Hermex connects here) |
| `hermesadmin.chrisvis.com` | Dashboard, `hermes-agent.railway.internal:8080` |

## Upgrading

- **Hermes:** change the tag and digest in `Dockerfile` after reading the [release notes](https://github.com/NousResearch/hermes-agent/releases). Never use `latest`.
- **WebUI:** change `HERMES_WEBUI_COMMIT` and `HERMES_WEBUI_VERSION` to a release commit.

Any push to `main` redeploys the service.

## 2026-10 layout migration

The volume used to mount at `/data` with Hermes data in `/data/.hermes`, which left the agent's home and working folder on temporary disk. On first boot with the volume at `/opt/data`, the entrypoint backs up `.hermes` to `/opt/data/.migration-backup-*.tar`, moves it to the top level and writes `/opt/data/.layout-v2`. `HERMES_MIGRATION_CLEANUP=1` deletes the backup on the next boot. If the move can't complete safely, it skips the migration and keeps running from `.hermes`.
