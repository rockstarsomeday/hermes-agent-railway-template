# Official Hermes image. Bump deliberately (tag + digest) after reading the
# upstream release notes.
FROM nousresearch/hermes-agent:v2026.9.24

# Hermes WebUI (https://github.com/nesquena/hermes-webui) runs in this same
# container so it shares HERMES_HOME (sessions, memory, skills, config) with
# the agent. Railway volumes cannot be mounted by two services.
# Pinned by commit (v0.52.458).
ARG HERMES_WEBUI_COMMIT=fd0141fa196fe832171c9c0551bbb8205b6412d4
ARG HERMES_WEBUI_VERSION=0.52.458
RUN mkdir /opt/hermes-webui && cd /opt/hermes-webui \
    && git init -q \
    && git fetch -q --depth 1 https://github.com/nesquena/hermes-webui "${HERMES_WEBUI_COMMIT}" \
    && git checkout -q FETCH_HEAD \
    && rm -rf .git tests \
    && echo "__version__ = '${HERMES_WEBUI_VERSION}'" > api/_version.py \
    && chown -R hermes:hermes /opt/hermes-webui

COPY s6-rc.d/webui/ /etc/s6-overlay/s6-rc.d/webui/
RUN chmod 0755 /etc/s6-overlay/s6-rc.d/webui/run /etc/s6-overlay/s6-rc.d/webui/finish \
    && touch /etc/s6-overlay/s6-rc.d/user/contents.d/webui

# Old /data paths (pre-2026-10 layout) keep resolving after the volume moved
# to /opt/data. Hidden by the volume while it is still mounted at /data.
RUN mkdir -p /data \
    && ln -s /opt/data /data/.hermes \
    && ln -s /opt/data/workspace /data/workspace

COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/hermes-railway-entrypoint

# HERMES_HOME stays at the upstream default (/opt/data); the volume mounts there.
ENV HERMES_DASHBOARD=1 \
    HERMES_GATEWAY_BOOTSTRAP_STATE=running \
    HERMES_WEBUI=1 \
    HERMES_WEBUI_HOST=0.0.0.0 \
    HERMES_WEBUI_PORT=8787 \
    HERMES_WEBUI_STATE_DIR=/opt/data/webui \
    HERMES_WEBUI_AGENT_DIR=/opt/hermes \
    HERMES_WEBUI_DEFAULT_WORKSPACE=/opt/data/workspace

ENTRYPOINT ["/usr/local/bin/hermes-railway-entrypoint"]
CMD ["gateway", "run"]
