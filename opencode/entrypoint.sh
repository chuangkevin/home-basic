#!/bin/sh
AUTH_FILE="/root/.local/share/opencode/auth.json"
CONFIG_FILE="/app/opencode.json"
DEFAULT_OPENCODE_CONFIG='{"model":"opencode/deepseek-v4-flash-free","small_model":"opencode/deepseek-v4-flash-free"}'
PREV_HASH=""

expected_config() {
  if [ -n "${OPENCODE_CONFIG_CONTENT:-}" ]; then
    printf '%s' "$OPENCODE_CONFIG_CONTENT"
  else
    printf '%s' "$DEFAULT_OPENCODE_CONFIG"
  fi
}

write_opencode_config() {
  CONFIG_CONTENT=$(expected_config)
  if ! EXPECTED_CONFIG="$CONFIG_CONTENT" node -e 'const config = JSON.parse(process.env.EXPECTED_CONFIG); if (!config || typeof config !== "object" || Array.isArray(config)) process.exit(1)' >/dev/null 2>&1; then
    echo "OPENCODE_CONFIG_CONTENT is not a valid JSON object; using built-in default config." >&2
    CONFIG_CONTENT="$DEFAULT_OPENCODE_CONFIG"
  fi

  printf '%s\n' "$CONFIG_CONTENT" > "$CONFIG_FILE.tmp"
  mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
}

opencode_config_is_healthy() {
  CONFIG_CONTENT=$(expected_config)
  EXPECTED_CONFIG="$CONFIG_CONTENT" DEFAULT_OPENCODE_CONFIG="$DEFAULT_OPENCODE_CONFIG" CONFIG_FILE="$CONFIG_FILE" node <<'NODE'
const fs = require("fs")

function parseConfig(value) {
  try {
    const parsed = JSON.parse(value)
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : null
  } catch {
    return null
  }
}

function stableStringify(value) {
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`
  }

  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableStringify(value[key])}`).join(",")}}`
  }

  return JSON.stringify(value)
}

const expected = parseConfig(process.env.EXPECTED_CONFIG) || parseConfig(process.env.DEFAULT_OPENCODE_CONFIG)
let current = null

try {
  current = parseConfig(fs.readFileSync(process.env.CONFIG_FILE, "utf8"))
} catch {
  current = null
}

if (!expected || !current) {
  process.exit(1)
}

const allowedKeys = new Set([...Object.keys(expected), "$schema"])

for (const key of Object.keys(expected)) {
  if (stableStringify(current[key]) !== stableStringify(expected[key])) {
    process.exit(1)
  }
}

for (const key of Object.keys(current)) {
  if (!allowedKeys.has(key)) {
    process.exit(1)
  }
}
NODE
}

write_opencode_config

while true; do
  if ! opencode_config_is_healthy; then
    echo "opencode.json is missing or invalid, repairing before start..."
    write_opencode_config
  fi

  opencode serve --hostname 0.0.0.0 --port 4096 --print-logs &
  OPENCODE_PID=$!

  while kill -0 $OPENCODE_PID 2>/dev/null; do
    CURR_HASH=$(md5sum "$AUTH_FILE" 2>/dev/null | cut -d' ' -f1)
    if [ -n "$PREV_HASH" ] && [ "$CURR_HASH" != "$PREV_HASH" ]; then
      echo "auth.json changed, restarting opencode..."
      PREV_HASH="$CURR_HASH"
      kill $OPENCODE_PID
      break
    fi
    PREV_HASH="$CURR_HASH"

    if ! opencode_config_is_healthy; then
      echo "opencode.json changed to an unexpected shape, repairing and restarting opencode..."
      write_opencode_config
      kill $OPENCODE_PID
      break
    fi

    sleep 3
  done

  wait $OPENCODE_PID
  sleep 1
done
