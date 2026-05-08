variable "endpoint" {
  description = "Kodo S3 兼容端点 (如 s3.cn-east-1.qiniucs.com)"
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

variable "ak" {
  description = "七牛云 Access Key"
  type        = string
  sensitive   = true
}

variable "sk" {
  description = "七牛云 Secret Key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Kodo 区域 (如 cn-east-1)"
  type        = string
  default     = "cn-east-1"
}

variable "poll_interval" {
  description = "Agent 轮询间隔 (秒)"
  type        = number
  default     = 3
}
