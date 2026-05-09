output "command_id" {
  description = "命令 ID (时间戳)"
  value       = local.cmd_id
}

output "exit_code" {
  description = "命令执行退出码"
  value       = jsondecode(data.local_file.result.content)["exit_code"]
}

output "output" {
  description = "命令执行输出内容"
  value       = jsondecode(data.local_file.result.content)["output"]
}

output "executed_at" {
  description = "命令执行完成时间"
  value       = jsondecode(data.local_file.result.content)["executed_at"]
}

output "result" {
  description = "完整的执行结果 JSON"
  value       = jsondecode(data.local_file.result.content)
}
