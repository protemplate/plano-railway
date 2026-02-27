# Plano Railway Template

Deploy [Plano](https://github.com/katanemo/plano) — an AI-native proxy for LLM routing, guardrails, and observability — on [Railway](https://railway.app) with one click.

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/template/1jWZbX)

## What is Plano?

Plano is an AI-native proxy built on Envoy that provides:

- **Unified LLM API** — OpenAI-compatible `/v1/chat/completions` endpoint that routes to any provider (OpenAI, Anthropic, Google, Groq, Mistral, DeepSeek, xAI, Together AI)
- **Intelligent Routing** — Automatically select the best model based on prompt intent using lightweight purpose-built LLMs
- **Guardrails** — Safety filters and jailbreak detection
- **Observability** — Auto-captured OpenTelemetry traces for every request

## Quick Start

1. Click the **Deploy on Railway** button above
2. Set at least one API key (e.g., `OPENAI_API_KEY`)
3. Deploy — Plano auto-generates its config from your environment variables

## Environment Variables

### LLM Provider Keys (at least one required)

| Variable | Provider |
|----------|----------|
| `OPENAI_API_KEY` | OpenAI |
| `ANTHROPIC_API_KEY` | Anthropic |
| `GOOGLE_API_KEY` | Google Gemini |
| `GROQ_API_KEY` | Groq |
| `MISTRAL_API_KEY` | Mistral |
| `DEEPSEEK_API_KEY` | DeepSeek |
| `XAI_API_KEY` | xAI (Grok) |
| `TOGETHER_API_KEY` | Together AI |

### Optional Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PLANO_DEFAULT_PROVIDER` | *(first key set)* | Default provider: `openai`, `anthropic`, `google`, etc. |
| `PLANO_OPENAI_MODEL` | `openai/gpt-4o` | Override OpenAI model |
| `PLANO_ANTHROPIC_MODEL` | `anthropic/claude-sonnet-4-5` | Override Anthropic model |
| `PLANO_TIMEOUT` | `30s` | Request timeout |
| `PLANO_TRACE_SAMPLING` | `0` | OpenTelemetry trace sampling (0-100) |
| `LOG_LEVEL` | `info` | Log level: `error`, `warn`, `info`, `debug` |

### Advanced: Custom Config

For full control over Plano's configuration (routing preferences, agents, guardrails), bypass auto-generation:

```bash
# Option A: Raw YAML
PLANO_CONFIG_YAML="version: v0.1.0
listeners:
  egress_traffic:
    address: 0.0.0.0
    port: 12000
    message_format: openai
model_providers:
  - model: openai/gpt-4o
    access_key: \$OPENAI_API_KEY
    default: true"

# Option B: Base64-encoded YAML
PLANO_CONFIG_BASE64=$(echo "$config" | base64)
```

See `config/default_config.yaml` for a full reference with all options.

## Usage

Once deployed, Plano exposes an OpenAI-compatible API:

```bash
# Replace with your Railway domain
PLANO_URL="https://your-plano.up.railway.app"

# Chat completion (routes to default provider)
curl "$PLANO_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openai/gpt-4o",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'

# Health check
curl "$PLANO_URL/healthz"
```

### Connecting Services via Private Networking

For services within the same Railway project, use private networking (faster, free):

```bash
# On your application service, set:
OPENAI_BASE_URL=http://${{Plano.RAILWAY_PRIVATE_DOMAIN}}:${{Plano.PORT}}/v1
```

**Important:** Always include the port in private network URLs.

## Architecture

| Port | Purpose | Railway Exposure |
|------|---------|-----------------|
| `$PORT` (default 12000) | LLM Gateway — OpenAI-compatible API | Public or private |
| 10000 (fixed) | Agent listener (if configured) | Private only |
| 9901 (fixed) | Envoy admin | Not exposed |

Plano is **stateless** — no volume needed. Configuration is generated at startup from environment variables.

## Local Development

```bash
# Copy and configure environment
cp .env.example .env
# Edit .env with your API keys

# Build and run
make run

# Test
curl http://localhost:12000/healthz
curl http://localhost:12000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"openai/gpt-4o","messages":[{"role":"user","content":"Hi"}]}'

# View logs
make logs

# Stop and clean up
make clean
```

## Intelligent Routing Example

With a custom config, Plano can automatically route requests to the cheapest suitable model:

```yaml
# Set via PLANO_CONFIG_YAML
version: v0.1.0

routing:
  model: Arch-Router
  llm_provider: arch-router

listeners:
  egress_traffic:
    address: 0.0.0.0
    port: 12000
    message_format: openai
    timeout: 30s

model_providers:
  - model: openai/gpt-4o-mini
    access_key: $OPENAI_API_KEY
    default: true
    routing_preferences:
      - name: general conversation
        description: general chat, greetings, Q&A, everyday questions

  - model: anthropic/claude-sonnet-4-5
    access_key: $ANTHROPIC_API_KEY
    routing_preferences:
      - name: code generation
        description: code generation, complex reasoning, analysis
```

Plano will route conversational requests to GPT-4o-mini (cheaper) and code/reasoning to Claude (more capable).

## Links

- [Plano GitHub](https://github.com/katanemo/plano)
- [Plano Documentation](https://docs.planoai.dev)
- [Railway Documentation](https://docs.railway.app)
