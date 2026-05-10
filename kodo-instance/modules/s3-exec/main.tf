terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

locals {
  cmd_id       = formatdate("YYYYMMDDhhmmss", timestamp())
  cmd_key      = "commands/${var.instance_id}/pending/${local.cmd_id}.cmd"
  result_key   = "results/${var.instance_id}/${local.cmd_id}.json"
  result_file  = "${path.module}/.result_cache/${var.instance_id}_${local.cmd_id}.json"
  endpoint_url = startswith(var.endpoint_url, "http://") || startswith(var.endpoint_url, "https://") ? var.endpoint_url : "https://${var.endpoint_url}"

  s3_client_py = file("${path.module}/../shared/s3_client.py")
  exec_py      = file("${path.module}/scripts/exec.py")

  command_blob_b64 = base64encode("${var.command_type}\n${var.command}")

  rendered = templatefile("${path.module}/templates/run-exec.sh", {
    s3_client_py     = local.s3_client_py
    exec_py          = local.exec_py
    bucket           = var.bucket
    instance_id      = var.instance_id
    command_blob_b64 = local.command_blob_b64
    command_file     = "${local.result_file}.cmd"
    result_file      = local.result_file
    result_dir       = dirname(local.result_file)
    timeout          = var.timeout
    poll_interval    = var.poll_interval
  })

  s3_env = merge(
    {
      PATH                  = "/usr/local/bin:/usr/bin:/bin"
      S3_ENDPOINT_URL       = local.endpoint_url
      S3_ACCESS_KEY_ID      = var.access_key_id
      S3_SECRET_ACCESS_KEY  = var.secret_access_key
      AWS_ACCESS_KEY_ID     = var.access_key_id
      AWS_SECRET_ACCESS_KEY = var.secret_access_key
    },
    var.session_token != null ? {
      S3_SESSION_TOKEN  = var.session_token
      AWS_SESSION_TOKEN = var.session_token
    } : {},
    var.region != null ? {
      S3_REGION          = var.region
      AWS_DEFAULT_REGION = var.region
      AWS_REGION         = var.region
    } : {}
  )
}

resource "terraform_data" "exec_command" {
  triggers_replace = {
    command      = var.command
    command_type = var.command_type
    cmd_id       = local.cmd_id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command     = local.rendered
    environment = local.s3_env
  }
}

data "local_file" "result" {
  filename   = local.result_file
  depends_on = [terraform_data.exec_command]
}
