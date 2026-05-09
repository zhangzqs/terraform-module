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
    instance_id  = var.instance_id
  }
}

data "external" "exec" {
  program = ["/usr/bin/python3", "${path.module}/scripts/exec.py"]

  query = {
    broker_host               = var.broker_host
    broker_port               = tostring(var.broker_port)
    topic_prefix              = var.topic_prefix
    instance_id               = var.instance_id
    task_uuid                 = random_uuid.task_uuid.result
    command_type              = var.command_type
    command                   = var.command
    timeout                   = tostring(var.timeout)
    poll_interval             = tostring(var.poll_interval)
    terraform_private_key_pem = var.terraform_private_key_pem
    terraform_certificate_pem = var.terraform_certificate_pem
    agent_certificate_pem     = var.agent_certificate_pem
  }
}
