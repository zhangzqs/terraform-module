terraform {
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = ">= 2.0"
    }
  }
}

data "external" "heartbeat" {
  program = ["/usr/bin/python3", "${path.module}/scripts/heartbeat.py"]

  query = {
    broker_host               = var.mqtt_config.broker_host
    broker_port               = tostring(var.mqtt_config.broker_port)
    topic_prefix              = var.mqtt_config.topic_prefix
    instance_id               = var.crypto_bundle.node_id
    timeout                   = tostring(var.timeout)
    poll_interval             = tostring(var.poll_interval)
    terraform_private_key_pem = var.crypto_bundle.terraform_private_key_pem
    terraform_certificate_pem = var.crypto_bundle.terraform_certificate_pem
    agent_certificate_pem     = var.crypto_bundle.agent_certificate_pem
  }
}
