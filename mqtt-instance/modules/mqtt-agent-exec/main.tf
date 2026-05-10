terraform {
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "random_uuid" "task_uuid" {
  keepers = {
    command      = var.command
    command_type = var.command_type
    node_id      = var.crypto_bundle.node_id
  }
}

data "external" "exec" {
  program = ["/usr/bin/python3", "${path.module}/scripts/exec.py"]

  query = {
    broker_host               = var.mqtt_config.broker_host
    broker_port               = tostring(var.mqtt_config.broker_port)
    topic_prefix              = var.mqtt_config.topic_prefix
    instance_id               = var.crypto_bundle.node_id
    task_uuid                 = random_uuid.task_uuid.result
    command_type              = var.command_type
    command                   = var.command
    timeout                   = tostring(var.timeout)
    poll_interval             = tostring(var.poll_interval)
    terraform_private_key_pem = var.crypto_bundle.terraform_private_key_pem
    terraform_certificate_pem = var.crypto_bundle.terraform_certificate_pem
    agent_certificate_pem     = var.crypto_bundle.agent_certificate_pem
  }
}
