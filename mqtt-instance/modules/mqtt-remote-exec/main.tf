data "qiniu_compute_images" "available_official_images" {
  type  = "Official"
  state = "Available"
}

locals {
  ubuntu_image_id = one([
    for item in data.qiniu_compute_images.available_official_images.items : item
    if item.os_distribution == "Ubuntu" && item.os_version == "24.04 LTS"
  ]).id
}

# 生成稳定的节点 ID（用于 MQTT topic）
resource "random_uuid" "node_id" {}

# 生成实例密码
resource "random_password" "instance_password" {
  length  = 16
  special = true
  lower   = true
  upper   = true
  numeric = true
}

# Terraform 侧私钥（用于对 agent 回传的结果解密）
resource "tls_private_key" "terraform_side" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "terraform_side" {
  private_key_pem       = tls_private_key.terraform_side.private_key_pem
  validity_period_hours = 24 * 365
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "client_auth",
    "server_auth",
  ]

  subject {
    common_name  = "mqtt-instance-terraform"
    organization = "terraform-module"
  }
}

# Agent 侧私钥（用于对命令解密）
resource "tls_private_key" "agent_side" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "agent_side" {
  private_key_pem       = tls_private_key.agent_side.private_key_pem
  validity_period_hours = 24 * 365
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "client_auth",
    "server_auth",
  ]

  subject {
    common_name  = "mqtt-instance-agent"
    organization = "terraform-module"
  }
}

# 合并的密钥/证书对象，传给 mqtt-agent 和 mqtt-exec
locals {
  crypto_bundle = {
    node_id                   = random_uuid.node_id.result
    agent_certificate_pem     = tls_self_signed_cert.agent_side.cert_pem
    agent_private_key_pem     = tls_private_key.agent_side.private_key_pem
    terraform_certificate_pem = tls_self_signed_cert.terraform_side.cert_pem
    terraform_private_key_pem = tls_private_key.terraform_side.private_key_pem
  }
}

# 部署 MQTT agent
module "mqtt_agent" {
  source = "../mqtt-agent"

  mqtt_broker_host  = var.mqtt_broker_host
  mqtt_broker_port  = var.mqtt_broker_port
  mqtt_topic_prefix = var.mqtt_topic_prefix
  crypto_bundle     = local.crypto_bundle
  poll_interval     = 3
}

# 创建计算实例
resource "qiniu_compute_instance" "node" {
  instance_type          = "ecs.t1.c1m2"
  image_id               = local.ubuntu_image_id
  system_disk_size       = 20
  password               = random_password.instance_password.result
  user_data              = module.mqtt_agent.rendered
  internet_max_bandwidth = 10
  internet_charge_type   = "Bandwidth"
}

# 等待 agent 启动
resource "time_sleep" "wait_agent_ready" {
  depends_on      = [qiniu_compute_instance.node]
  create_duration = "30s"

  triggers = {
    instance_id = qiniu_compute_instance.node.id
  }
}

# 执行命令（通过 MQTT）
module "mqtt_exec" {
  source = "../mqtt-exec"

  mqtt_broker_host  = var.mqtt_broker_host
  mqtt_broker_port  = var.mqtt_broker_port
  mqtt_topic_prefix = var.mqtt_topic_prefix
  crypto_bundle     = local.crypto_bundle
  command_type      = var.command_type
  command           = var.command
  timeout           = var.mqtt_command_timeout

  depends_on = [time_sleep.wait_agent_ready]
}
