locals {
  s3_client_py = file("${path.module}/../shared/s3_client.py")
  agent_py     = file("${path.module}/scripts/agent.py")

  rendered = templatefile("${path.module}/templates/user-data.sh", {
    s3_client_py      = local.s3_client_py
    agent_py          = local.agent_py
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
