output "rendered" {
  description = "渲染后的 cloud-init 内容 (base64 编码)，传给实例的 user_data"
  value       = base64encode(local.rendered)
}
