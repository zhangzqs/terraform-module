#!/bin/bash
set -euo pipefail

# 安装依赖 (Ubuntu 24.04 没有 awscli 包，用 pip 安装)
apt-get update
apt-get install -y python3-pip python3 unzip curl
pip3 install --break-system-packages awscli

# 写入 agent 脚本 (base64 编码避免 heredoc 变量冲突)
mkdir -p /opt/s3-agent
echo '${agent_script_b64}' | base64 -d > /opt/s3-agent/agent.sh
chmod +x /opt/s3-agent/agent.sh

# 写入运行时环境，供 agent 启动时读取
cat > /etc/s3-agent.env << 'ENV_EOF'
S3_ACCESS_KEY_ID=${access_key_id}
S3_SECRET_ACCESS_KEY=${secret_access_key}
S3_SESSION_TOKEN=${session_token}
S3_ENDPOINT_URL=${endpoint_url}
S3_REGION=${region}
POLL_INTERVAL=${poll_interval}
ENV_EOF
chmod 600 /etc/s3-agent.env

# 写入 systemd 服务
cat > /etc/systemd/system/s3-agent.service << 'SERVICE_EOF'
[Unit]
Description=S3 Command Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/s3-agent/agent.sh ${bucket} ${instance_id}
EnvironmentFile=/etc/s3-agent.env
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# 启动服务
systemctl daemon-reload
systemctl enable s3-agent
systemctl start s3-agent
