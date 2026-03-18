#!/bin/bash
set -e

# ==============================================================================
# Plano Railway Template - Entrypoint Script
# Processes config/default_config.yaml template and starts supervisord
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
# Template processor
# ==============================================================================

# Evaluate a condition from # @if directives.
# Supports: VAR, VAR1 && VAR2, VAR1 && VAR2!=value
eval_condition() {
    local cond="$1"
    if [[ "$cond" == *" && "* ]]; then
        local left="${cond%% && *}"
        local right="${cond##* && }"
        # Left side: must be non-empty
        if [ -z "${!left}" ]; then return 1; fi
        # Right side: VAR or VAR!=value
        if [[ "$right" == *"!="* ]]; then
            local var="${right%%!=*}"
            local val="${right##*!=}"
            local actual="${!var:-true}"
            [ "$actual" = "$val" ] && return 1
        else
            [ -z "${!right}" ] && return 1
        fi
        return 0
    else
        [ -n "${!cond}" ] && return 0 || return 1
    fi
}

# Process a template file: evaluate @if/@endif/@default/@enddefault conditionals,
# resolve {{VAR:-default}} placeholders, pass $VAR through for Plano.
process_template() {
    local input="$1" output="$2"
    local -a stack=()
    local result="" prev_blank=false

    while IFS= read -r line || [ -n "$line" ]; do
        # @if directive
        if [[ "$line" =~ ^#\ @if\ (.+)$ ]]; then
            if eval_condition "${BASH_REMATCH[1]}"; then
                stack+=("1")
            else
                stack+=("0")
            fi
            continue
        fi

        # @endif directive
        if [[ "$line" == "# @endif" ]]; then
            if [ ${#stack[@]} -eq 0 ]; then
                echo "ERROR: @endif without matching @if in template" >&2; exit 1
            fi
            unset 'stack[${#stack[@]}-1]'
            continue
        fi

        # @default directive
        if [[ "$line" =~ ^#\ @default\ (.+)$ ]]; then
            if [ "$PLANO_DEFAULT_PROVIDER" = "${BASH_REMATCH[1]}" ]; then
                stack+=("1")
            else
                stack+=("0")
            fi
            continue
        fi

        # @enddefault directive
        if [[ "$line" == "# @enddefault" ]]; then
            if [ ${#stack[@]} -eq 0 ]; then
                echo "ERROR: @enddefault without matching @default in template" >&2; exit 1
            fi
            unset 'stack[${#stack[@]}-1]'
            continue
        fi

        # Check if current block is active (all stack entries are 1)
        local active=true
        for s in "${stack[@]}"; do
            if [ "$s" = "0" ]; then active=false; break; fi
        done

        if $active; then
            # Resolve {{VAR:-default}} placeholders (skip comment lines)
            while [[ "$line" != \#* ]] && [[ "$line" =~ \{\{([A-Za-z_][A-Za-z_0-9]*):-([^}]*)\}\} ]]; do
                local var_name="${BASH_REMATCH[1]}"
                local default_val="${BASH_REMATCH[2]}"
                local val="${!var_name}"
                [ -z "$val" ] && val="$default_val"
                local match="${BASH_REMATCH[0]}"
                line="${line%%"$match"*}${val}${line#*"$match"}"
            done

            # Collapse consecutive blank lines
            if [ -z "$line" ]; then
                if $prev_blank; then continue; fi
                prev_blank=true
            else
                prev_blank=false
            fi

            result+="$line"$'\n'
        fi
    done < "$input"

    # Write output, trim trailing blank lines
    while [[ "$result" == *$'\n'$'\n' ]]; do
        result="${result%$'\n'}"
    done
    printf '%s\n' "$result" > "$output"
}

# ==============================================================================
# Config generation (3 modes)
# ==============================================================================

CONFIG_PATH="/app/plano_config.yaml"
TEMPLATE_PATH="/app/default_config.yaml"

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
    # Mode 3: Process template with environment variables
    echo ""
    echo "Config mode: template (default_config.yaml)"

    # --- Pre-compute derived variables ---

    # Resolve default provider
    PLANO_DEFAULT_PROVIDER="${PLANO_DEFAULT_PROVIDER:-}"
    [ "$PLANO_DEFAULT_PROVIDER" = "gemini" ] && PLANO_DEFAULT_PROVIDER=google
    [ "$PLANO_DEFAULT_PROVIDER" = "together_ai" ] && PLANO_DEFAULT_PROVIDER=together

    # Count providers and auto-detect default
    PROVIDER_COUNT=0
    check_provider() {
        local display="$1" name="$2" key_var="$3" model_var="$4" default_model="$5"
        if [ -n "${!key_var}" ]; then
            PROVIDER_COUNT=$((PROVIDER_COUNT + 1))
            local model="${!model_var:-$default_model}"
            echo "  Provider: $display ($model)"
            [ -z "$PLANO_DEFAULT_PROVIDER" ] && PLANO_DEFAULT_PROVIDER="$name"
        fi
    }

    check_provider "OpenAI" openai OPENAI_API_KEY PLANO_OPENAI_MODEL "openai/gpt-4o"
    check_provider "Anthropic" anthropic ANTHROPIC_API_KEY PLANO_ANTHROPIC_MODEL "anthropic/claude-sonnet-4-5"
    check_provider "Google" google GOOGLE_API_KEY PLANO_GOOGLE_MODEL "gemini/gemini-2.5-flash"
    check_provider "Groq" groq GROQ_API_KEY PLANO_GROQ_MODEL "groq/llama-3.3-70b-versatile"
    check_provider "Mistral" mistral MISTRAL_API_KEY PLANO_MISTRAL_MODEL "mistral/mistral-large-latest"
    check_provider "DeepSeek" deepseek DEEPSEEK_API_KEY PLANO_DEEPSEEK_MODEL "deepseek/deepseek-chat"
    check_provider "xAI" xai XAI_API_KEY PLANO_XAI_MODEL "xai/grok-3"
    check_provider "Together AI" together TOGETHER_API_KEY PLANO_TOGETHER_MODEL "together_ai/meta-llama/Llama-3.3-70B-Instruct-Turbo"

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
    echo "  Total providers: $PROVIDER_COUNT, default: $PLANO_DEFAULT_PROVIDER"

    # Trace sampling
    TRACE_SAMPLING="${PLANO_TRACE_SAMPLING:-0}"
    if [ "$TRACE_SAMPLING" -gt 0 ] 2>/dev/null; then
        export __TRACE_ENABLED__=true
    fi

    # Process the template
    process_template "$TEMPLATE_PATH" "$CONFIG_PATH"

fi

# Log generated config (mask API keys)
echo ""
echo "Generated config:"
sed 's/\(access_key:\s*\).*/\1***/' "$CONFIG_PATH"
echo ""

# Start supervisord (Plano's process manager)
exec /usr/local/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
