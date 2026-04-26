#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_PATH="${1:-$REPO_ROOT/config/config.yaml}"
if [[ "$CONFIG_PATH" != /* ]]; then
  CONFIG_PATH="$(pwd)/$CONFIG_PATH"
fi
HISTORY="${MONITOR_HISTORY:-$REPO_ROOT/monitor_history.log}"

interval_minutes="$(python3 -c "import sys; sys.path.insert(0,sys.argv[2]); from config_loader import load_config; c=load_config(sys.argv[1]); print(c.get('monitor',{}).get('interval_minutes') or 10)" "$CONFIG_PATH" "$REPO_ROOT/analyzer" 2>/dev/null)"
interval_minutes="${interval_minutes:-10}"
if ! [[ "$interval_minutes" =~ ^[0-9]+$ ]] || [[ "$interval_minutes" -lt 1 ]]; then
  interval_minutes=10
fi

printf '[monitor] Running every %s minute(s). Press Ctrl+C to stop.\n' "$interval_minutes"
while true; do
  printf '[%s] cycle started\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "$HISTORY"

  "$SCRIPT_DIR/collect_logs.sh" "$CONFIG_PATH"
  collect_exit=$?
  printf '[%s] collect exit=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$collect_exit" >> "$HISTORY"

  if [[ "$collect_exit" -eq 0 ]]; then
    python3 "$REPO_ROOT/analyzer/analyze_logs.py" --config "$CONFIG_PATH"
    analyze_exit=$?
    printf '[%s] analyze exit=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$analyze_exit" >> "$HISTORY"
  fi

  sleep "$((interval_minutes * 60))"
done
