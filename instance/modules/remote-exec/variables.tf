variable "endpoint" {
  description = "Kodo S3 兼容端点 (如 s3.cn-east-1.qiniucs.com)"
  type        = string
}

variable "bucket" {
  description = "用于命令队列的 Kodo Bucket 名称"
  type        = string
}

variable "instance_id" {
  description = "目标实例 ID，用于隔离不同实例的命令通道"
  type        = string
}

variable "command" {
  description = "要执行的命令内容"
  type        = string
}

variable "command_type" {
  description = "命令类型: shell (单行命令) 或 shell-script (脚本)"
  type        = string
  default     = "shell"

  validation {
    condition     = contains(["shell", "shell-script"], var.command_type)
    error_message = "command_type 必须是 shell 或 shell-script"
  }
}

variable "timeout" {
  description = "等待命令执行完成的超时时间 (秒)"
  type        = number
  default     = 120
}

variable "poll_interval" {
  description = "轮询结果的间隔 (秒)"
  type        = number
  default     = 3
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
