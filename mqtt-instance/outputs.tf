output "public_ip" {
  description = "实例公网 IP"
  value       = qiniu_compute_instance.node.public_ip_addresses
}

output "instance_id" {
  description = "七牛云实例 ID"
  value       = qiniu_compute_instance.node.id
}

output "node_id" {
  description = "MQTT 节点 ID"
  value       = module.mqtt_agent_helper.node_id
}

output "heartbeat_received" {
  description = "Agent heartbeat received confirmation"
  value       = module.mqtt_agent_heartbeat.heartbeat_received
}

output "exec_result" {
  description = "MQTT 命令执行结果"
  value       = module.mqtt_agent_exec.result
  sensitive   = true
}

output "task_uuid" {
  description = "任务 UUID"
  value       = try(module.mqtt_agent_exec.result.task_uuid, "")
}

