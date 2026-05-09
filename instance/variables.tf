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
