locals {
  agent_script_b64 = base64encode(file("${path.module}/templates/agent.sh"))

  rendered = templatefile("${path.module}/templates/user-data.sh", {
    agent_script_b64  = local.agent_script_b64
    bucket            = var.bucket
    instance_id       = var.instance_id
    access_key_id     = var.access_key_id
    secret_access_key = var.secret_access_key
    endpoint_url      = var.endpoint_url
    session_token     = var.session_token == null ? "" : var.session_token
    region            = var.region == null ? "" : var.region
    poll_interval     = var.poll_interval
  })
}
