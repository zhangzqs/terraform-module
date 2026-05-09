variable "qiniu_access_key" {
  description = "七牛云 Access Key"
  type        = string
  sensitive   = true
}

variable "qiniu_secret_key" {
  description = "七牛云 Secret Key"
  type        = string
  sensitive   = true
}

variable "kodo_region" {
  description = "S3 兼容区域 (如 cn-east-1)"
  type        = string
  default     = "cn-east-1"
}

variable "command_bucket" {
  description = "用于命令队列的 S3 bucket 名称"
  type        = string
}

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

variable "mqtt_command_timeout" {
  description = "等待任务完成的超时时间 (秒)"
  type        = number
  default     = 900
}
