#!/bin/sh
AUTH_FILE="/root/.local/share/opencode/auth.json"
PREV_HASH=""

while true; do
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
    sleep 3
  done

  wait $OPENCODE_PID
  sleep 1
done
