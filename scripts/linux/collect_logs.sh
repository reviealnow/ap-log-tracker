#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_PATH="${1:-$REPO_ROOT/config/config.yaml}"
if [[ "$CONFIG_PATH" != /* ]]; then
  CONFIG_PATH="$(pwd)/$CONFIG_PATH"
fi

stage() {
  printf '[collect] %s\n' "$1"
}

fail() {
  printf '[ERROR] %s\n' "$1" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || fail "python3 is required."
command -v ssh >/dev/null 2>&1 || fail "ssh is required."
command -v scp >/dev/null 2>&1 || fail "scp is required."

config_json="$(python3 -c "import sys; sys.path.insert(0,sys.argv[2]); from config_loader import dump_json; print(dump_json(sys.argv[1]))" "$CONFIG_PATH" "$REPO_ROOT/analyzer")" \
  || fail "Unable to read $CONFIG_PATH. Install requirements with: pip install -r requirements.txt"

cfg() {
  python3 -c 'import json,sys; data=json.loads(sys.argv[1]); cur=data
for part in sys.argv[2].split("."):
    cur=cur.get(part, "") if isinstance(cur, dict) else ""
print("" if cur is None else cur)' "$config_json" "$1"
}

require() {
  local value="$1"
  local name="$2"
  [[ -n "$value" ]] || fail "Missing required config value: $name"
}

sanitize() {
  local value="${1:-$2}"
  printf '%s' "$value" | tr -cs '[:alnum:]_.-' '_'
}

PI_HOST="$(cfg raspberry_pi.host)"
PI_USER="$(cfg raspberry_pi.username)"
PI_PORT="$(cfg raspberry_pi.ssh_port)"
CAPTURE_PATH="$(cfg raspberry_pi.minicom_capture_path)"
REMOTE_LOG_DIR="$(cfg raspberry_pi.remote_log_dir)"
DUT_IP="$(cfg dut.ip)"
DUT_LABEL="$(sanitize "$(cfg dut.label)" "DUT-01")"
DUT_MARK="$(sanitize "$(cfg dut.mark)" "01")"
FIRMWARE="$(sanitize "$(cfg dut.firmware_version)" "unknown-fw")"
TFTP_SERVER_IP="$(cfg control_machine.tftp_server_ip)"
TFTP_ROOT="$(cfg control_machine.tftp_root)"
OUTPUT_DIR="$(cfg control_machine.output_dir)"
KEEP_CAPTURE="$(cfg monitor.keep_minicom_cap_after_upload)"

OUTPUT_DIR="${OUTPUT_DIR:-output}"
if [[ "$OUTPUT_DIR" != /* ]]; then
  OUTPUT_DIR="$REPO_ROOT/$OUTPUT_DIR"
fi
PI_PORT="${PI_PORT:-22}"
require "$PI_HOST" "raspberry_pi.host"
require "$PI_USER" "raspberry_pi.username"
require "$CAPTURE_PATH" "raspberry_pi.minicom_capture_path"
require "$REMOTE_LOG_DIR" "raspberry_pi.remote_log_dir"
require "$DUT_IP" "dut.ip"

timestamp="$(date +%m%d_%H%M%S)"
file_name="${FIRMWARE}-${timestamp}-log-${DUT_LABEL}-${DUT_MARK}-DUT_${DUT_IP}.txt"
base_name="${file_name%.txt}"
raw_dir="${OUTPUT_DIR}/raw"
mkdir -p "$raw_dir"
if [[ -n "$TFTP_ROOT" && "$TFTP_ROOT" != /* ]]; then
  TFTP_ROOT="$REPO_ROOT/$TFTP_ROOT"
fi
[[ -z "$TFTP_ROOT" ]] || mkdir -p "$TFTP_ROOT"

memory_pattern='MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapCached|Active|Inactive|Slab|SReclaimable|SUnreclaim'
keep_flag="false"
[[ "$KEEP_CAPTURE" == "True" || "$KEEP_CAPTURE" == "true" ]] && keep_flag="true"
q_capture_path="$(printf '%q' "$CAPTURE_PATH")"
q_remote_log_dir="$(printf '%q' "$REMOTE_LOG_DIR")"
q_tftp_server_ip="$(printf '%q' "$TFTP_SERVER_IP")"
q_keep_flag="$(printf '%q' "$keep_flag")"

stage "Checking Raspberry Pi capture file on ${PI_USER}@${PI_HOST}"
remote_script="$(printf '%s\n' \
  'set -e' \
  'expand_path() {' \
  '  case "$1" in' \
  '    "~") printf "%s\n" "$HOME" ;;' \
  '    "~/"*) printf "%s/%s\n" "$HOME" "${1#~/}" ;;' \
  '    *) printf "%s\n" "$1" ;;' \
  '  esac' \
  '}' \
  "capture_path=\$(expand_path $q_capture_path)" \
  "remote_log_dir=\$(expand_path $q_remote_log_dir)" \
  "tftp_server_ip=$q_tftp_server_ip" \
  "keep_capture=$q_keep_flag" \
  'mkdir -p "$remote_log_dir"' \
  'test -f "$capture_path"' \
  "cp \"\$capture_path\" \"\$remote_log_dir/$file_name\"" \
  "perl -pi -e 's/%%/%/g' \"\$remote_log_dir/$file_name\"" \
  "grep -E 'CPU[0-9]' \"\$remote_log_dir/$file_name\" > \"\$remote_log_dir/${base_name}_cpu.txt\" || true" \
  "grep -E '$memory_pattern' \"\$remote_log_dir/$file_name\" > \"\$remote_log_dir/${base_name}_memory.txt\" || true" \
  'if [ -n "$tftp_server_ip" ]; then' \
  '  command -v tftp >/dev/null 2>&1 || exit 31' \
  '  cd "$remote_log_dir"' \
  "  tftp \"\$tftp_server_ip\" -c put \"$file_name\" || exit 30" \
  "  tftp \"\$tftp_server_ip\" -c put \"${base_name}_cpu.txt\" || exit 30" \
  "  tftp \"\$tftp_server_ip\" -c put \"${base_name}_memory.txt\" || exit 30" \
  'fi' \
  'if [ "$keep_capture" = "false" ]; then' \
  '  rm -f "$capture_path"' \
  'fi')"

ssh -p "$PI_PORT" "${PI_USER}@${PI_HOST}" "bash -lc $(printf '%q' "$remote_script")" \
  || fail "Remote collection failed. Check SSH, minicom capture path, and optional TFTP access."

stage "Copying collected files to $raw_dir"
scp -P "$PI_PORT" "${PI_USER}@${PI_HOST}:${REMOTE_LOG_DIR}/${file_name}" "$raw_dir/" \
  || fail "SCP failed for raw log."
scp -P "$PI_PORT" "${PI_USER}@${PI_HOST}:${REMOTE_LOG_DIR}/${base_name}_cpu.txt" "$raw_dir/" || true
scp -P "$PI_PORT" "${PI_USER}@${PI_HOST}:${REMOTE_LOG_DIR}/${base_name}_memory.txt" "$raw_dir/" || true

if [[ -n "$TFTP_ROOT" ]]; then
  stage "Mirroring collected files into configured TFTP root: $TFTP_ROOT"
  cp -f "$raw_dir/$file_name" "$TFTP_ROOT/"
  cp -f "$raw_dir/${base_name}_cpu.txt" "$TFTP_ROOT/" 2>/dev/null || true
  cp -f "$raw_dir/${base_name}_memory.txt" "$TFTP_ROOT/" 2>/dev/null || true
fi

stage "Done: $file_name"
