data "qiniu_compute_images" "available_official_images" {
  type  = "Official"
  state = "Available"
}

locals {
  ubuntu_image_id = one([
    for item in data.qiniu_compute_images.available_official_images.items : item
    if item.os_distribution == "Ubuntu" && item.os_version == "24.04 LTS"
  ]).id

  s3_endpoint = "s3.${var.kodo_region}.qiniucs.com"
}

resource "random_password" "instance_password" {
  length  = 16
  special = true
  lower   = true
  upper   = true
  numeric = true
}

resource "random_uuid" "instance_id" {}

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

module "mqtt_agent" {
  source = "./modules/mqtt-agent"

  broker_host               = var.mqtt_broker_host
  broker_port               = var.mqtt_broker_port
  topic_prefix              = var.mqtt_topic_prefix
  instance_id               = random_uuid.instance_id.result
  agent_certificate_pem     = tls_self_signed_cert.agent_side.cert_pem
  agent_private_key_pem     = tls_private_key.agent_side.private_key_pem
  terraform_certificate_pem = tls_self_signed_cert.terraform_side.cert_pem
  poll_interval             = 3
}

resource "qiniu_compute_instance" "node" {
  instance_type          = "ecs.t1.c1m2"
  image_id               = local.ubuntu_image_id
  system_disk_size       = 20
  password               = random_password.instance_password.result
  user_data              = module.mqtt_agent.rendered
  internet_max_bandwidth = 10
  internet_charge_type   = "Bandwidth"
}

resource "time_sleep" "wait_agent_ready" {
  depends_on      = [qiniu_compute_instance.node]
  create_duration = "30s"

  triggers = {
    instance_id = qiniu_compute_instance.node.id
  }
}

module "mqtt_exec" {
  source = "./modules/mqtt-exec"

  broker_host               = var.mqtt_broker_host
  broker_port               = var.mqtt_broker_port
  topic_prefix              = var.mqtt_topic_prefix
  instance_id               = random_uuid.instance_id.result
  command_type              = "shell-script"
  command                   = <<-SCRIPT
    apt-get update
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
  SCRIPT
  timeout                   = var.mqtt_command_timeout
  terraform_private_key_pem = tls_private_key.terraform_side.private_key_pem
  terraform_certificate_pem = tls_self_signed_cert.terraform_side.cert_pem
  agent_certificate_pem     = tls_self_signed_cert.agent_side.cert_pem

  depends_on = [time_sleep.wait_agent_ready]
}

output "public_ip" {
  description = "实例公网 IP"
  value       = qiniu_compute_instance.node.public_ip_addresses
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
