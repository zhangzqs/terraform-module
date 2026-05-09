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

  aws_env = merge(
    {
      PATH                  = "/usr/local/bin:/usr/bin:/bin:${pathexpand("~/.local/bin")}"
      AWS_ACCESS_KEY_ID     = var.access_key_id
      AWS_SECRET_ACCESS_KEY = var.secret_access_key
    },
    var.session_token != null ? { AWS_SESSION_TOKEN = var.session_token } : {},
    var.region != null ? { AWS_DEFAULT_REGION = var.region } : {}
  )
}

resource "terraform_data" "exec_command" {
  triggers_replace = {
    command      = var.command
    command_type = var.command_type
    cmd_id       = local.cmd_id
  }

  provisioner "local-exec" {
    environment = local.aws_env
    command     = <<-EOT
      set -e
      ENDPOINT="${local.endpoint_url}"
      BUCKET="${var.bucket}"

      # 上传命令
      mkdir -p "${path.module}/.result_cache"
      echo '${base64encode("${var.command_type}\n${var.command}")}' | base64 -d |         aws s3 cp - "s3://$BUCKET/${local.cmd_key}" --endpoint-url "$ENDPOINT"
      echo "Command uploaded: ${local.cmd_key}"

      # 轮询结果
      SECONDS=0
      while [ $SECONDS -lt ${var.timeout} ]; do
        if aws s3 ls "s3://$BUCKET/${local.result_key}" --endpoint-url "$ENDPOINT" > /dev/null 2>&1; then
          aws s3 cp "s3://$BUCKET/${local.result_key}" "${local.result_file}" --endpoint-url "$ENDPOINT"
          echo "Result saved: ${local.result_file}"
          EXIT_CODE=$(python3 -c "import json; print(json.load(open('${local.result_file}'))['exit_code'])")
          exit $EXIT_CODE
        fi
        sleep ${var.poll_interval}
      done
      echo "Timeout after ${var.timeout}s"
      exit 1
    EOT
  }
}

data "local_file" "result" {
  filename   = local.result_file
  depends_on = [terraform_data.exec_command]
}
