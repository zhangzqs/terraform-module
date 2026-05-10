#!/bin/bash
set -euo pipefail

mkdir -p "${result_dir}"
cat > "${result_dir}/s3_client.py" <<'PY'
${s3_client_py}
PY
cat > "${result_dir}/exec.py" <<'PY'
${exec_py}
PY
chmod 600 "${result_dir}/s3_client.py" "${result_dir}/exec.py"

printf '%s' '${command_blob_b64}' | base64 -d > "${command_file}"
chmod 600 "${command_file}"

python3 "${result_dir}/exec.py" \
  --bucket "${bucket}" \
  --instance-id "${instance_id}" \
  --command-file "${command_file}" \
  --result-file "${result_file}" \
  --timeout "${timeout}" \
  --poll-interval "${poll_interval}"
