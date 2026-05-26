# OpenCode Provider

This directory runs a small OpenCode provider service plus a browser chat UI. It is used by HomeProject services that need a shared OpenCode/OpenAI backend.

## HomeProject Deployment Notes

- Canonical provider URL: `https://provider-amd.sisihome.org`.
- Kevinhome provider URL: `https://provider-home.sisihome.org`.
- Do not add or use `https://opencode-amd.sisihome.org`; that hostname is not part of the deployment contract.
- The amd64 provider runs on the Manjaro host (`100.73.52.37`) and is exposed on port `4096`.
- The Kevinhome provider runs on `100.83.112.20`, container `provider-home`, host port `4098` -> container port `4096`; RPi Caddy routes `provider-home.sisihome.org` to `100.83.112.20:4098`.
- The browser chat UI is served by Caddy on host port `3000` (local compose) or `3002` (Kevinhome compose). Caddy reverse-proxies `/api/*` to the internal `opencode:4096` service, so the browser only ever talks to its own origin and there is no CORS layer to fight.
- Both compose files publish opencode's API port for direct consumers: local `docker-compose.yml` exposes `4096:4096`, Kevinhome `docker-compose.home.yml` exposes `4098:4096`. The Caddy `/api` proxy on the web container is for browsers; service-to-service callers can keep hitting the opencode port directly.
- The provider is intentionally no-auth on the private network. Do not set `OPENCODE_SERVER_PASSWORD` for this deployment, and do not make consumers send Basic auth or custom provider passwords.
- Use `network_mode: host` for the amd64 provider if Docker published ports produce connection resets/refusals.
- Browser-callback OAuth (`localhost:1455`) is no longer supported by the compose files; the UI only offers the ChatGPT Pro/Plus headless / device-code flow, which does not need a callback port. Do not republish `1455:1455` unless you are intentionally reintroducing browser OAuth on a localhost-only deployment.
- On remote k3s / NodePort deployments, do not use OpenAI browser OAuth by default. Browser OAuth redirects to the user's own `localhost:1455`, not the pod. Use headless/device-code auth unless you intentionally port-forward local `1455` to the remote `opencode` service.
- After `auth.json` changes, the entrypoint restarts `opencode` once to reload provider state. The watcher must update its hash baseline before killing the process; otherwise a successful OAuth write causes an infinite restart loop and `/provider` returns 502.
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

The disabled `OpenAI (browser callback, needs localhost:1455)` option is intentionally inert in both compose files. Re-enable it only on a localhost-only deployment where you have also republished `1455:1455`.

## Web UI Routing

The chat UI is served by Caddy. The frontend calls relative URLs under `/api`, and Caddy reverse-proxies them to the internal `opencode:4096` service:

```
browser  ──>  http://<host>:3000/api/provider        (same-origin)
caddy    ──>  http://opencode:4096/provider          (docker network)
```

There is no cross-origin layer to fight. If you are tempted to point the frontend directly at port `4096`, stop: opencode's CORS allowlist only echoes `Access-Control-Allow-Origin` for `localhost` / `127.0.0.1`, so any other hostname (LAN host, Tailscale name, container ID) will silently fail with `Failed to fetch` in the browser despite the API being reachable via `curl`.

## Remote K8s / NodePort OAuth Pitfall

For deployments like `srvhpgit1:32096` where the chat UI is served through Kubernetes and the provider runs in a pod, OpenAI browser OAuth is misleading: the callback URL is still `http://localhost:1455/auth/callback`, and that `localhost` belongs to the browser user's machine. If the user has another local Docker / WSL process bound to `1455`, the callback can hit the wrong process and OpenCode will eventually timeout.

Use the headless/device-code option for remote deployments. If browser OAuth is required for debugging, first ensure nothing local owns `1455`, then run a local port-forward to the remote service:

```powershell
kubectl --kubeconfig D:\Projects\argo-app\k3s-srvhpgit1測試機.yaml -n home-basic port-forward svc/opencode 1455:1455
```

If the UI says auth completed but the model list changes to `載入失敗`, check for an `auth.json` restart loop:

```powershell
kubectl --kubeconfig D:\Projects\argo-app\k3s-srvhpgit1測試機.yaml logs deploy/opencode -n home-basic --tail=120
curl.exe -i --max-time 20 http://srvhpgit1:32096/provider
```

Repeated `auth.json changed, restarting opencode...` means the watcher baseline is stale. The fix is to set `PREV_HASH="$CURR_HASH"` before killing the process.

The Web UI must also retry model loading after OAuth. A successful token write restarts OpenCode once, so `/provider` can briefly return 502. Do not leave `loadModels()` as a single-shot fetch after auth; retry with backoff and show a temporary `模型重載中...` state.

On page refresh, the Web UI should infer whether OpenAI is already connected from `/provider` instead of resetting the Connect button to an unauthenticated state. For OpenAI OAuth, a loaded provider with `options.apiKey` means the token is already persisted and usable.

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
