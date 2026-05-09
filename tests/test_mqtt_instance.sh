#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

cd mqtt-instance
terraform init -backend=false -input=false
terraform fmt -check -recursive
terraform validate
python3 -m py_compile \
  modules/shared/mqtt_crypto.py \
  modules/mqtt-agent/scripts/agent.py \
  modules/mqtt-exec/scripts/exec.py

cd ..
python3 tests/test_mqtt_crypto_roundtrip.py
