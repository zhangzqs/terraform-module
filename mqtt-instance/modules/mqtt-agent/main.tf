locals {
  shared_py = file("${path.module}/../shared/mqtt_crypto.py")
  agent_py  = file("${path.module}/scripts/agent.py")

  rendered = templatefile("${path.module}/templates/user-data.sh", {
    shared_py                 = local.shared_py
    agent_py                  = local.agent_py
    broker_host               = var.broker_host
    broker_port               = var.broker_port
    topic_prefix              = var.topic_prefix
    instance_id               = var.instance_id
    poll_interval             = var.poll_interval
    replay_window_seconds     = var.replay_window_seconds
    ledger_path               = var.ledger_path
    max_workers               = var.max_workers
    python_executable         = var.python_executable
    agent_certificate_pem     = var.agent_certificate_pem
    agent_private_key_pem     = var.agent_private_key_pem
    terraform_certificate_pem = var.terraform_certificate_pem
  })
}
