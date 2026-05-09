#!/bin/bash
set -euo pipefail

mkdir -p /opt/s3-agent
cat > /opt/s3-agent/s3_client.py <<'PY'
${s3_client_py}
PY
cat > /opt/s3-agent/agent.py <<'PY'
${agent_py}
PY
chmod 600 /opt/s3-agent/s3_client.py /opt/s3-agent/agent.py
chmod +x /opt/s3-agent/agent.py

cat > /etc/s3-agent.env << 'ENV_EOF'
S3_ACCESS_KEY_ID=${access_key_id}
S3_SECRET_ACCESS_KEY=${secret_access_key}
S3_SESSION_TOKEN=${session_token}
S3_ENDPOINT_URL=${endpoint_url}
S3_REGION=${region}
POLL_INTERVAL=${poll_interval}
ENV_EOF
chmod 600 /etc/s3-agent.env

cat > /etc/systemd/system/s3-agent.service << 'SERVICE_EOF'
[Unit]
Description=S3 Command Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/s3-agent/agent.py ${bucket} ${instance_id}
EnvironmentFile=/etc/s3-agent.env
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable s3-agent
systemctl start s3-agent
