output "heartbeat_received" {
  description = "Whether heartbeat was successfully received from agent"
  value       = data.external.heartbeat.result.received == "true"
}

output "result" {
  description = "Full result from heartbeat script"
  value       = data.external.heartbeat.result
  sensitive   = true
}
