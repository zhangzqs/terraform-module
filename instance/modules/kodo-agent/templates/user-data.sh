#!/bin/bash
set -euo pipefail

# 安装依赖 (Ubuntu 24.04 没有 awscli 包，用 pip 安装)
apt-get update
apt-get install -y python3-pip python3 unzip curl
pip3 install --break-system-packages awscli

# 写入 agent 脚本 (base64 编码避免 heredoc 变量冲突)
mkdir -p /opt/kodo-agent
echo '${agent_script_b64}' | base64 -d > /opt/kodo-agent/agent.sh
chmod +x /opt/kodo-agent/agent.sh

# 写入 systemd 服务
cat > /etc/systemd/system/kodo-agent.service << 'SERVICE_EOF'
[Unit]
Description=Kodo Command Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/kodo-agent/agent.sh ${bucket} ${instance_id}
Environment="AWS_ACCESS_KEY_ID=${ak}"
Environment="AWS_SECRET_ACCESS_KEY=${sk}"
Environment="S3_ENDPOINT=${endpoint}"
Environment="AWS_DEFAULT_REGION=${region}"
Environment="POLL_INTERVAL=${poll_interval}"
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# 启动服务
systemctl daemon-reload
systemctl enable kodo-agent
systemctl start kodo-agent
