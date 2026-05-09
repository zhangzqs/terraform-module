variable "endpoint_url" {
  description = "S3 兼容端点 URL (如 https://s3.example.com)"
  type        = string
}

variable "bucket" {
  description = "命令队列使用的 Kodo Bucket 名称"
  type        = string
}

variable "instance_id" {
  description = "实例 ID，用于隔离不同实例的命令通道"
  type        = string
}

variable "access_key_id" {
  description = "S3 Access Key ID"
  type        = string
  sensitive   = true
}

variable "secret_access_key" {
  description = "S3 Secret Access Key"
  type        = string
  sensitive   = true
}

variable "session_token" {
  description = "S3 Session Token（可选）"
  type        = string
  default     = null
  sensitive   = true
}

variable "region" {
  description = "S3 区域（可选）"
  type        = string
  default     = null
}

variable "poll_interval" {
  description = "Agent 轮询间隔 (秒)"
  type        = number
  default     = 3
}
