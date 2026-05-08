locals {
  agent_script_b64 = base64encode(file("${path.module}/templates/agent.sh"))

  rendered = templatefile("${path.module}/templates/user-data.sh", {
    agent_script_b64 = local.agent_script_b64
    bucket           = var.bucket
    instance_id      = var.instance_id
    ak               = var.ak
    sk               = var.sk
    endpoint         = var.endpoint
    region           = var.region
    poll_interval    = var.poll_interval
  })
}
