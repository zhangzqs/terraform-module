output "node_id" {
  description = "MQTT topic 节点 ID"
  value       = local.crypto_bundle.node_id
}

output "public_ip" {
  description = "实例公网 IP"
  value       = qiniu_compute_instance.node.public_ip_addresses
}

output "instance_id" {
  description = "七牛云实例 ID"
  value       = qiniu_compute_instance.node.id
}

output "exec_result" {
  description = "MQTT 命令执行结果"
  value = {
    task_uuid   = module.mqtt_exec.task_uuid
    exit_code   = module.mqtt_exec.exit_code
    output      = module.mqtt_exec.output
    executed_at = module.mqtt_exec.executed_at
  }
}
