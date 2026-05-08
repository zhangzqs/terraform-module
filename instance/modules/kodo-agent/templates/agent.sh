#!/bin/bash
# Kodo Command Agent - 轮询 Kodo 对象存储执行远程命令
# 依赖: aws-cli, python3
set -euo pipefail

BUCKET="$1"
INSTANCE_ID="$2"
POLL_INTERVAL="${POLL_INTERVAL:-3}"

COMMANDS_PREFIX="commands/${INSTANCE_ID}/pending"
RESULTS_PREFIX="results/${INSTANCE_ID}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }

process_commands() {
  local keys
  keys=$(aws s3api list-objects-v2 \
    --bucket "$BUCKET" \
    --prefix "${COMMANDS_PREFIX}/" \
    --query 'Contents[].Key' \
    --output text 2>/dev/null || true)

  [ -z "$keys" ] && return

  for key in $keys; do
    local cmd_id
    cmd_id=$(basename "$key" .cmd)

    log "Processing: ${cmd_id}"

    local cmd_content
    cmd_content=$(aws s3 cp "s3://${BUCKET}/${key}" - 2>/dev/null)

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
    python3 -c "
import json, sys
data = {
    'command_id': '${cmd_id}',
    'instance_id': '${INSTANCE_ID}',
    'exit_code': ${exit_code},
    'output': sys.stdin.read(),
    'executed_at': '$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
json.dump(data, sys.stdout, ensure_ascii=False)
" <<< "$output" > "$result_file"

    aws s3 cp "$result_file" "s3://${BUCKET}/${RESULTS_PREFIX}/${cmd_id}.json" 2>/dev/null
    rm -f "$result_file"

    # 归档命令
    aws s3 cp "s3://${BUCKET}/${key}" \
      "s3://${BUCKET}/commands/${INSTANCE_ID}/done/${cmd_id}.cmd" 2>/dev/null
    aws s3 rm "s3://${BUCKET}/${key}" 2>/dev/null

    log "Done: ${cmd_id} (exit=${exit_code})"
  done
}

log "Agent started: instance=${INSTANCE_ID}, bucket=${BUCKET}, interval=${POLL_INTERVAL}s"

while true; do
  process_commands || log "Error in process_commands"
  sleep "$POLL_INTERVAL"
done
