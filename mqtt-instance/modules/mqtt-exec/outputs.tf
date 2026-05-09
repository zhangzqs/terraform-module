output "task_uuid" {
  description = "任务 UUID"
  value       = data.external.exec.result.task_uuid
}

output "exit_code" {
  description = "命令退出码"
  value       = tonumber(data.external.exec.result.exit_code)
}

output "output" {
  description = "命令输出"
  value       = data.external.exec.result.output
}

output "executed_at" {
  description = "命令执行时间"
  value       = data.external.exec.result.executed_at
}
