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
  description = "实例 ID"
  type        = string
}

variable "command_type" {
  description = "命令类型"
  type        = string
  default     = "shell"

  validation {
    condition     = contains(["shell", "shell-script"], var.command_type)
    error_message = "command_type 必须是 shell 或 shell-script"
  }
}

variable "command" {
  description = "要执行的命令"
  type        = string
}

variable "timeout" {
  description = "等待执行结果超时时间 (秒)"
  type        = number
  default     = 900
}

variable "poll_interval" {
  description = "轮询间隔 (秒)"
  type        = number
  default     = 3
}

variable "terraform_private_key_pem" {
  description = "Terraform 侧私钥"
  type        = string
  sensitive   = true
}

variable "terraform_certificate_pem" {
  description = "Terraform 侧证书"
  type        = string
}

variable "agent_certificate_pem" {
  description = "VM 侧证书"
  type        = string
}
