# OpenCode Provider

This directory runs a small OpenCode provider service plus a browser chat UI. It is used by HomeProject services that need a shared OpenCode/OpenAI backend.

## HomeProject Deployment Notes

- Canonical provider URL: `https://provider-amd.sisihome.org`.
- Kevinhome provider URL: `https://provider-home.sisihome.org`.
- Do not add or use `https://opencode-amd.sisihome.org`; that hostname is not part of the deployment contract.
- The amd64 provider runs on the Manjaro host (`100.73.52.37`) and is exposed on port `4096`.
- The Kevinhome provider runs on `100.83.112.20`, container `provider-home`, host port `4098` -> container port `4096`; RPi Caddy routes `provider-home.sisihome.org` to `100.83.112.20:4098`.
- The browser chat UI runs on `http://100.73.52.37:3000` and calls port `4096` on the same hostname.
- The Kevinhome browser chat UI runs on `http://100.83.112.20:3002` via container `provider-home-web`.
- The provider is intentionally no-auth on the private network. Do not set `OPENCODE_SERVER_PASSWORD` for this deployment, and do not make consumers send Basic auth or custom provider passwords.
- Use `network_mode: host` for the amd64 provider if Docker published ports produce connection resets/refusals.
- The browser OAuth callback port is `1455`. If Windows cannot bind `localhost:1455`, use the Manjaro Tailscale host callback URL and preserve the full query string.
- On Kevinhome, Docker cannot bind host port `1455` because Windows reserves it; `docker-compose.home.yml` intentionally does not publish `1455`. The Web UI defaults OpenAI OAuth to `ChatGPT Pro/Plus (headless)` device-code auth, which avoids localhost callback. Keep provider API health separate from OAuth callback setup.
- Provider images are pinned to `opencode-ai@1.15.5` until the `1.15.6` OpenAI message model resolver regression is cleared.

## Kevinhome Deployment

Run from this directory:

```bash
docker compose -p provider-home -f docker-compose.home.yml up -d --build
```

Verify:

```bash
curl https://provider-home.sisihome.org/global/health
```

## Kevinhome OpenAI OAuth

Kevinhome Windows reserves TCP port `1455`, so the OpenAI browser callback flow cannot reach `localhost:1455` from the browser. Use device-code auth instead:

1. Open the browser chat UI at `http://100.83.112.20:3002`.
2. Click `Connect`.
3. Keep the default provider option: `OpenAI (ChatGPT Pro/Plus - headless/device code)`.
4. Click `開始驗證`.
5. Copy the displayed `Enter code: XXXX-XXXXX` code.
6. Open `https://auth.openai.com/codex/device` if the UI did not open it automatically.
7. Enter the code and finish OpenAI login in the browser.
8. Return to the chat UI and click `完成驗證` to save the token into the provider.

Do not use `OpenAI (browser callback, needs localhost:1455)` on Kevinhome unless Windows no longer reserves port `1455` and the compose file publishes that port.

## Consumer API Contract

OpenCode's session creation and message payloads do not use the same model key names.

Create a session with `id` and `variant`. For OpenAI reasoning models such as `gpt-5.5`, use `medium` unless a different reasoning effort is explicitly needed:

```json
{
  "title": "my-service",
  "agent": "general",
  "model": {
    "providerID": "openai",
    "id": "gpt-5.5",
    "variant": "medium"
  }
}
```

Send a message with `modelID`, and pass the same variant at the message body level:

```json
{
  "agent": "general",
  "model": {
    "providerID": "openai",
    "modelID": "gpt-5.5"
  },
  "variant": "medium",
  "parts": [
    { "type": "text", "text": "Hello" }
  ]
}
```

Known bad shapes return `BadRequest`, for example `Missing key at ["model"]["modelID"]` when a message uses the session-style `id` key.

## Routing Lessons

- If a public domain is backed by CI/CD, route the domain to the CI/CD-managed container, not a fallback local app container.
- For `sheet-to-car`, the intended mapping is `car.sisihome.org -> RPi:5223` for `:dev`, and `carsmeet.sisihome.org -> Manjaro:5224` for `:latest`.
- Do not recreate retired `sheet-to-car-test` container or DB names; live containers are `sheet-to-car` for dev/car and `sheet-to-car-prod` for prod/carsmeet.

## Verification

- Health checks: `GET https://provider-amd.sisihome.org/global/health` and `GET https://provider-home.sisihome.org/global/health` should return `{"healthy":true}`.
- Available OAuth/API auth methods can be checked with `GET /provider/auth`.
- Smoke test with `providerID=openai`, `modelID=gpt-5.5`, `variant=medium`, and prompt text that expects a deterministic short response.
