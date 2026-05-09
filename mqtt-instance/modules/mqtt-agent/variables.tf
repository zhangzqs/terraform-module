variable "broker_host" {
  description = "MQTT broker 主机名"
  type        = string
}

variable "broker_port" {
  description = "MQTT broker TLS 端口"
  type        = number
}

variable "topic_prefix" {
  description = "MQTT topic 前缀"
  type        = string
}

variable "instance_id" {
  description = "实例 ID，用于隔离 topic"
  type        = string
}

variable "agent_certificate_pem" {
  description = "VM 侧证书"
  type        = string
}

variable "agent_private_key_pem" {
  description = "VM 侧私钥"
  type        = string
  sensitive   = true
}

variable "terraform_certificate_pem" {
  description = "Terraform 侧证书，用于验签 command"
  type        = string
}

variable "poll_interval" {
  description = "Agent 主循环轮询/重连间隔"
  type        = number
  default     = 3
}

variable "replay_window_seconds" {
  description = "反重放时间窗（秒）。需大于 agent 最长启动时间，避免 retained 命令因时间窗过期被拒绝"
  type        = number
  default     = 3600
}

variable "ledger_path" {
  description = "任务幂等落盘路径"
  type        = string
  default     = "/var/lib/mqtt-agent/tasks.jsonl"
}

variable "max_workers" {
  description = "并发执行任务数"
  type        = number
  default     = 4
}

variable "python_executable" {
  description = "Python 解释器路径"
  type        = string
  default     = "/usr/bin/python3"
}
