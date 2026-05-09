#!/bin/bash
# S3 Command Agent - 轮询 S3-compatible object storage执行远程命令
# 依赖: aws-cli, python3
set -euo pipefail

if [ -f /etc/s3-agent.env ]; then
  set -a
  . /etc/s3-agent.env
  set +a
fi

S3_ENDPOINT_URL="${S3_ENDPOINT_URL:-}"
case "$S3_ENDPOINT_URL" in
  http://*|https://*) ;;
  *) S3_ENDPOINT_URL="https://${S3_ENDPOINT_URL}" ;;
esac

export AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY_ID:-${AWS_ACCESS_KEY_ID:-}}"
export AWS_SECRET_ACCESS_KEY="${S3_SECRET_ACCESS_KEY:-${AWS_SECRET_ACCESS_KEY:-}}"
export AWS_SESSION_TOKEN="${S3_SESSION_TOKEN:-${AWS_SESSION_TOKEN:-}}"
if [ -n "${S3_REGION:-}" ]; then
  export AWS_REGION="${S3_REGION}"
  export AWS_DEFAULT_REGION="${S3_REGION}"
fi

BUCKET="$1"
INSTANCE_ID="$2"
POLL_INTERVAL="${POLL_INTERVAL:-3}"
S3_ENDPOINT="$S3_ENDPOINT_URL"

COMMANDS_PREFIX="commands/${INSTANCE_ID}/pending"
RESULTS_PREFIX="results/${INSTANCE_ID}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }

process_commands() {
  local keys
  keys=$(aws s3api list-objects-v2 \
    --bucket "$BUCKET" \
    --prefix "${COMMANDS_PREFIX}/" \
    --query 'Contents[].Key' \
    --output text \
    --endpoint-url "$S3_ENDPOINT" 2>/dev/null || true)

  [ -z "$keys" ] && return

  for key in $keys; do
    local cmd_id
    cmd_id=$(basename "$key" .cmd)

    log "Processing: ${cmd_id}"

    local cmd_content
    cmd_content=$(aws s3 cp "s3://${BUCKET}/${key}" - --endpoint-url "$S3_ENDPOINT" 2>/dev/null)

    local cmd_type cmd_body
    cmd_type=$(echo "$cmd_content" | head -1)
    cmd_body=$(echo "$cmd_content" | tail -n +2)

    local output exit_code=0
    case "$cmd_type" in
      shell)
        output=$(eval "$cmd_body" 2>&1) || exit_code=$?
        ;;
      shell-script)
        local tmp_script
        tmp_script=$(mktemp /tmp/cmd_XXXXXX.sh)
        echo "$cmd_body" > "$tmp_script"
        chmod +x "$tmp_script"
        output=$(bash "$tmp_script" 2>&1) || exit_code=$?
        rm -f "$tmp_script"
        ;;
      *)
        output="Unknown command type: ${cmd_type}"
        exit_code=1
        ;;
    esac

    # 写结果
    local result_file
    result_file=$(mktemp)
    RESULT_OUTPUT="$output" python3 - "$cmd_id" "$INSTANCE_ID" "$exit_code" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" <<'PY' > "$result_file"
import json
import os
import sys

cmd_id, instance_id, exit_code, executed_at = sys.argv[1:5]
data = {
    "command_id": cmd_id,
    "instance_id": instance_id,
    "exit_code": int(exit_code),
    "output": os.environ.get("RESULT_OUTPUT", ""),
    "executed_at": executed_at,
}
json.dump(data, sys.stdout, ensure_ascii=False)
PY

    aws s3 cp "$result_file" "s3://${BUCKET}/${RESULTS_PREFIX}/${cmd_id}.json" --endpoint-url "$S3_ENDPOINT" 2>/dev/null
    rm -f "$result_file"

    # 归档命令
    aws s3 cp "s3://${BUCKET}/${key}" \
      "s3://${BUCKET}/commands/${INSTANCE_ID}/done/${cmd_id}.cmd" --endpoint-url "$S3_ENDPOINT" 2>/dev/null
    aws s3 rm "s3://${BUCKET}/${key}" --endpoint-url "$S3_ENDPOINT" 2>/dev/null

    log "Done: ${cmd_id} (exit=${exit_code})"
  done
}

log "Agent started: instance=${INSTANCE_ID}, bucket=${BUCKET}, interval=${POLL_INTERVAL}s"

while true; do
  process_commands || log "Error in process_commands"
  sleep "$POLL_INTERVAL"
done
