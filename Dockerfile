# Plano Railway Template
# Thin wrapper around the official Plano image with Railway PORT handling
ARG PLANO_VERSION=0.4.8
FROM katanemo/plano:${PLANO_VERSION}

# curl is already in the base image (used for health checks)

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy reference config (not used at runtime — entrypoint generates config from env vars)
COPY config/default_config.yaml /app/default_config.yaml

# LLM Gateway port (Railway overrides via $PORT)
EXPOSE 12000

# Health check on the LLM gateway listener
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:${PORT:-12000}/healthz || exit 1

# Custom entrypoint generates config then starts supervisord
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
