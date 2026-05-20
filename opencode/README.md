# OpenCode Provider

This directory runs a small OpenCode provider service plus a browser chat UI. It is used by HomeProject services that need a shared OpenCode/OpenAI backend.

## HomeProject Deployment Notes

- Canonical provider URL: `https://provider-amd.sisihome.org`.
- Do not add or use `https://opencode-amd.sisihome.org`; that hostname is not part of the deployment contract.
- The amd64 provider runs on the Manjaro host (`100.73.52.37`) and is exposed on port `4096`.
- The browser chat UI runs on `http://100.73.52.37:3000` and calls port `4096` on the same hostname.
- The provider is intentionally no-auth on the private network. Do not set `OPENCODE_SERVER_PASSWORD` for this deployment, and do not make consumers send Basic auth or custom provider passwords.
- Use `network_mode: host` for the amd64 provider if Docker published ports produce connection resets/refusals.
- The browser OAuth callback port is `1455`. If Windows cannot bind `localhost:1455`, use the Manjaro Tailscale host callback URL and preserve the full query string.

## Consumer API Contract

OpenCode's session creation and message payloads do not use the same model key names.

Create a session with `id` and `variant`:

```json
{
  "title": "my-service",
  "agent": "general",
  "model": {
    "providerID": "openai",
    "id": "gpt-5.5",
    "variant": "default"
  }
}
```

Send a message with `modelID`:

```json
{
  "agent": "general",
  "model": {
    "providerID": "openai",
    "modelID": "gpt-5.5"
  },
  "parts": [
    { "type": "text", "text": "Hello" }
  ]
}
```

Known bad shapes return `BadRequest`, for example `Missing key at ["model"]["modelID"]` when a message uses the session-style `id` key.

## Routing Lessons

- If a public domain is backed by CI/CD, route the domain to the CI/CD-managed container, not a fallback local app container.
- For `sheet-to-car`, the intended mapping is `car.sisihome.org -> Manjaro:5223` for `:dev`, and `carsmeet.sisihome.org -> Manjaro:5224` for `:latest`.
- RPi Caddy may be a fallback reverse proxy, but it should forward those app hostnames to Manjaro rather than serving stale local containers.

## Verification

- Health check: `GET https://provider-amd.sisihome.org/global/health` should return `{"healthy":true}`.
- Available OAuth/API auth methods can be checked with `GET /provider/auth`.
- Smoke test with `providerID=openai`, `modelID=gpt-5.5`, and prompt text that expects a deterministic short response.
