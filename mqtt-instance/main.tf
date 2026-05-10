module "mqtt_remote_exec" {
  source = "./modules/mqtt-remote-exec"

  mqtt_broker_host     = var.mqtt_broker_host
  mqtt_broker_port     = var.mqtt_broker_port
  mqtt_topic_prefix    = var.mqtt_topic_prefix
  mqtt_command_timeout = var.mqtt_command_timeout
  command_type         = var.command_type
  command              = var.command
}

output "public_ip" {
  description = "实例公网 IP"
  value       = module.mqtt_remote_exec.public_ip
}

output "instance_id" {
  description = "七牛云实例 ID"
  value       = module.mqtt_remote_exec.instance_id
}

output "node_id" {
  description = "MQTT 节点 ID"
  value       = module.mqtt_remote_exec.node_id
}

output "exec_result" {
  description = "MQTT 命令执行结果"
  value       = module.mqtt_remote_exec.exec_result
}

output "task_uuid" {
  description = "任务 UUID"
  value       = module.mqtt_remote_exec.exec_result.task_uuid
}
