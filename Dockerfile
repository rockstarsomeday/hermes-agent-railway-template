FROM nousresearch/hermes-agent:v2026.9.24

# Hermes WebUI (https://github.com/nesquena/hermes-webui) runs in this same
# container so it shares /data/.hermes (sessions, memory, skills, config) with
# the agent. Railway volumes cannot be mounted by two services.
ARG HERMES_WEBUI_REF=v0.52.458
RUN git clone --depth 1 --branch "${HERMES_WEBUI_REF}" \
        https://github.com/nesquena/hermes-webui /opt/hermes-webui \
    && rm -rf /opt/hermes-webui/.git /opt/hermes-webui/tests \
    && echo "__version__ = '${HERMES_WEBUI_REF#v}'" > /opt/hermes-webui/api/_version.py \
    && chown -R hermes:hermes /opt/hermes-webui

COPY s6-rc.d/webui/ /etc/s6-overlay/s6-rc.d/webui/
RUN chmod 0755 /etc/s6-overlay/s6-rc.d/webui/run /etc/s6-overlay/s6-rc.d/webui/finish \
    && touch /etc/s6-overlay/s6-rc.d/user/contents.d/webui

COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/hermes-railway-entrypoint

ENV HERMES_HOME=/data/.hermes \
    HERMES_WRITE_SAFE_ROOT=/data/.hermes \
    HERMES_LAZY_INSTALL_TARGET=/data/.hermes/lazy-packages \
    HERMES_DASHBOARD=1 \
    HERMES_DASHBOARD_HOST=0.0.0.0 \
    HERMES_GATEWAY_BOOTSTRAP_STATE=running \
    HERMES_WEBUI=1 \
    HERMES_WEBUI_HOST=0.0.0.0 \
    HERMES_WEBUI_PORT=8787 \
    HERMES_WEBUI_STATE_DIR=/data/.hermes/webui \
    HERMES_WEBUI_AGENT_DIR=/opt/hermes

ENTRYPOINT ["/usr/local/bin/hermes-railway-entrypoint"]
CMD ["gateway", "run"]
