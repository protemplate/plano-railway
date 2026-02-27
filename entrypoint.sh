#!/bin/bash
set -e

# ==============================================================================
# Plano Railway Template - Entrypoint Script
# Generates plano_config.yaml from environment variables and starts supervisord
# ==============================================================================

# Railway provides PORT environment variable
PLANO_PORT="${PORT:-12000}"

echo ""
echo "Plano Railway Template"
echo "======================"
echo "LLM Gateway port: $PLANO_PORT"

if [ -n "$RAILWAY_PRIVATE_DOMAIN" ]; then
    echo ""
    echo "Service accessible at:"
    echo "  - Public:  via your Railway public domain"
    echo "  - Private: http://$RAILWAY_PRIVATE_DOMAIN:$PLANO_PORT"
    echo ""
    echo "IMPORTANT: Always include :$PLANO_PORT when connecting via private networking!"
fi

# ==============================================================================
# Config generation (3 modes)
# ==============================================================================

CONFIG_PATH="/app/plano_config.yaml"

if [ -n "$PLANO_CONFIG_YAML" ]; then
    # Mode 1: Full YAML config from environment variable
    echo ""
    echo "Config mode: PLANO_CONFIG_YAML (raw YAML from env var)"
    echo "$PLANO_CONFIG_YAML" > "$CONFIG_PATH"

elif [ -n "$PLANO_CONFIG_BASE64" ]; then
    # Mode 2: Base64-encoded config
    echo ""
    echo "Config mode: PLANO_CONFIG_BASE64 (base64 decoded)"
    echo "$PLANO_CONFIG_BASE64" | base64 -d > "$CONFIG_PATH"

else
    # Mode 3: Auto-generate from individual env vars
    echo ""
    echo "Config mode: auto-generate from environment variables"

    # Determine default provider
    DEFAULT_PROVIDER="${PLANO_DEFAULT_PROVIDER:-}"

    # Build model_providers section
    PROVIDERS=""
    PROVIDER_COUNT=0

    if [ -n "$OPENAI_API_KEY" ]; then
        MODEL="${PLANO_OPENAI_MODEL:-openai/gpt-4o}"
        IS_DEFAULT=""
        if [ "$DEFAULT_PROVIDER" = "openai" ] || { [ -z "$DEFAULT_PROVIDER" ] && [ $PROVIDER_COUNT -eq 0 ]; }; then
            IS_DEFAULT=$'\n    default: true'
        fi
        ROUTING_PREFS=""
        if [ -n "$PLANO_ROUTING_MODEL" ]; then
            ROUTING_PREFS=$'\n    routing_preferences:\n      - name: general conversation\n        description: general chat, greetings, Q&A, everyday questions, casual conversation'
        fi
        PROVIDERS="${PROVIDERS}
  - model: ${MODEL}
    access_key: \$OPENAI_API_KEY${IS_DEFAULT}${ROUTING_PREFS}"
        PROVIDER_COUNT=$((PROVIDER_COUNT + 1))
        echo "  Provider: OpenAI ($MODEL)"
    fi

    if [ -n "$ANTHROPIC_API_KEY" ]; then
        MODEL="${PLANO_ANTHROPIC_MODEL:-anthropic/claude-sonnet-4-5}"
        IS_DEFAULT=""
        if [ "$DEFAULT_PROVIDER" = "anthropic" ] || { [ -z "$DEFAULT_PROVIDER" ] && [ $PROVIDER_COUNT -eq 0 ]; }; then
            IS_DEFAULT=$'\n    default: true'
        fi
        ROUTING_PREFS=""
        if [ -n "$PLANO_ROUTING_MODEL" ]; then
            ROUTING_PREFS=$'\n    routing_preferences:\n      - name: code generation\n        description: generating code, writing scripts, complex reasoning, analysis, debugging'
        fi
        PROVIDERS="${PROVIDERS}
  - model: ${MODEL}
    access_key: \$ANTHROPIC_API_KEY${IS_DEFAULT}${ROUTING_PREFS}"
        PROVIDER_COUNT=$((PROVIDER_COUNT + 1))
        echo "  Provider: Anthropic ($MODEL)"
    fi

    if [ -n "$GOOGLE_API_KEY" ]; then
        MODEL="${PLANO_GOOGLE_MODEL:-gemini/gemini-2.5-flash}"
        IS_DEFAULT=""
        if [ "$DEFAULT_PROVIDER" = "google" ] || [ "$DEFAULT_PROVIDER" = "gemini" ]; then
            IS_DEFAULT=$'\n    default: true'
        fi
        ROUTING_PREFS=""
        if [ -n "$PLANO_ROUTING_MODEL" ]; then
            ROUTING_PREFS=$'\n    routing_preferences:\n      - name: general conversation\n        description: general chat, greetings, Q&A, everyday questions, summarization'
        fi
        PROVIDERS="${PROVIDERS}
  - model: ${MODEL}
    access_key: \$GOOGLE_API_KEY${IS_DEFAULT}${ROUTING_PREFS}"
        PROVIDER_COUNT=$((PROVIDER_COUNT + 1))
        echo "  Provider: Google ($MODEL)"
    fi

    if [ -n "$GROQ_API_KEY" ]; then
        MODEL="${PLANO_GROQ_MODEL:-groq/llama-3.3-70b-versatile}"
        IS_DEFAULT=""
        if [ "$DEFAULT_PROVIDER" = "groq" ]; then
            IS_DEFAULT=$'\n    default: true'
        fi
        ROUTING_PREFS=""
        if [ -n "$PLANO_ROUTING_MODEL" ]; then
            ROUTING_PREFS=$'\n    routing_preferences:\n      - name: quick tasks\n        description: fast responses, simple questions, quick lookups, brief answers'
        fi
        PROVIDERS="${PROVIDERS}
  - model: ${MODEL}
    access_key: \$GROQ_API_KEY${IS_DEFAULT}${ROUTING_PREFS}"
        PROVIDER_COUNT=$((PROVIDER_COUNT + 1))
        echo "  Provider: Groq ($MODEL)"
    fi

    if [ -n "$MISTRAL_API_KEY" ]; then
        MODEL="${PLANO_MISTRAL_MODEL:-mistral/mistral-large-latest}"
        IS_DEFAULT=""
        if [ "$DEFAULT_PROVIDER" = "mistral" ]; then
            IS_DEFAULT=$'\n    default: true'
        fi
        PROVIDERS="${PROVIDERS}
  - model: ${MODEL}
    access_key: \$MISTRAL_API_KEY${IS_DEFAULT}"
        PROVIDER_COUNT=$((PROVIDER_COUNT + 1))
        echo "  Provider: Mistral ($MODEL)"
    fi

    if [ -n "$DEEPSEEK_API_KEY" ]; then
        MODEL="${PLANO_DEEPSEEK_MODEL:-deepseek/deepseek-chat}"
        IS_DEFAULT=""
        if [ "$DEFAULT_PROVIDER" = "deepseek" ]; then
            IS_DEFAULT=$'\n    default: true'
        fi
        PROVIDERS="${PROVIDERS}
  - model: ${MODEL}
    access_key: \$DEEPSEEK_API_KEY${IS_DEFAULT}"
        PROVIDER_COUNT=$((PROVIDER_COUNT + 1))
        echo "  Provider: DeepSeek ($MODEL)"
    fi

    if [ -n "$XAI_API_KEY" ]; then
        MODEL="${PLANO_XAI_MODEL:-xai/grok-3}"
        IS_DEFAULT=""
        if [ "$DEFAULT_PROVIDER" = "xai" ]; then
            IS_DEFAULT=$'\n    default: true'
        fi
        PROVIDERS="${PROVIDERS}
  - model: ${MODEL}
    access_key: \$XAI_API_KEY${IS_DEFAULT}"
        PROVIDER_COUNT=$((PROVIDER_COUNT + 1))
        echo "  Provider: xAI ($MODEL)"
    fi

    if [ -n "$TOGETHER_API_KEY" ]; then
        MODEL="${PLANO_TOGETHER_MODEL:-together_ai/meta-llama/Llama-3.3-70B-Instruct-Turbo}"
        IS_DEFAULT=""
        if [ "$DEFAULT_PROVIDER" = "together" ] || [ "$DEFAULT_PROVIDER" = "together_ai" ]; then
            IS_DEFAULT=$'\n    default: true'
        fi
        PROVIDERS="${PROVIDERS}
  - model: ${MODEL}
    access_key: \$TOGETHER_API_KEY${IS_DEFAULT}"
        PROVIDER_COUNT=$((PROVIDER_COUNT + 1))
        echo "  Provider: Together AI ($MODEL)"
    fi

    if [ $PROVIDER_COUNT -eq 0 ]; then
        echo ""
        echo "ERROR: No API keys configured!"
        echo "Set at least one of: OPENAI_API_KEY, ANTHROPIC_API_KEY, GOOGLE_API_KEY,"
        echo "GROQ_API_KEY, MISTRAL_API_KEY, DEEPSEEK_API_KEY, XAI_API_KEY, TOGETHER_API_KEY"
        echo ""
        echo "Or provide a full config via PLANO_CONFIG_YAML or PLANO_CONFIG_BASE64"
        exit 1
    fi

    echo ""
    echo "  Total providers: $PROVIDER_COUNT"

    # Build routing section (only if multiple providers with routing enabled)
    ROUTING_SECTION=""
    if [ -n "$PLANO_ROUTING_MODEL" ]; then
        ROUTING_SECTION="
routing:
  model: ${PLANO_ROUTING_MODEL}
  llm_provider: ${PLANO_ROUTING_PROVIDER:-arch-router}"
    fi

    # Build tracing section
    TRACING_SECTION=""
    TRACE_SAMPLING="${PLANO_TRACE_SAMPLING:-0}"
    if [ "$TRACE_SAMPLING" -gt 0 ] 2>/dev/null; then
        TRACING_SECTION="
tracing:
  random_sampling: ${TRACE_SAMPLING}"
    fi

    # Generate the config
    cat > "$CONFIG_PATH" <<YAML
version: v0.1.0
${ROUTING_SECTION}
listeners:
  egress_traffic:
    address: 0.0.0.0
    port: ${PLANO_PORT}
    message_format: openai
    timeout: ${PLANO_TIMEOUT:-30s}

model_providers:${PROVIDERS}
${TRACING_SECTION}
YAML

fi

# Log generated config (mask API keys)
echo ""
echo "Generated config:"
sed 's/\(access_key:\s*\).*/\1***/' "$CONFIG_PATH"
echo ""

# Start supervisord (Plano's process manager)
exec /usr/local/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
