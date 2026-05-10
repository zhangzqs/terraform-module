variable "mqtt_broker_host" {
  description = "MQTT broker 主机名"
  type        = string
  default     = "broker.emqx.io"
}

variable "mqtt_broker_port" {
  description = "MQTT broker TLS 端口"
  type        = number
  default     = 8883
}

variable "mqtt_topic_prefix" {
  description = "MQTT topic 前缀"
  type        = string
  default     = "mqtt-instance"
}

variable "mqtt_config" {
  description = "MQTT broker 配置（从 broker_host/port/topic_prefix 衍生）"
  type = object({
    broker_host  = string
    broker_port  = number
    topic_prefix = string
  })
  default = null
}

variable "mqtt_command_timeout" {
  description = "等待任务完成的超时时间 (秒)"
  type        = number
  default     = 900
}

variable "command_type" {
  description = "命令类型 (shell-script, binary)"
  type        = string
  default     = "shell-script"
}

variable "command" {
  description = "要执行的命令内容"
  type        = string
  default     = "apt-get update && apt-get install -y nginx && systemctl enable nginx && systemctl start nginx"
}

variable "root_password" {
  description = "实例 root 密码"
  type        = string
  sensitive   = true
  default     = "TerraformDefault123!"
}
