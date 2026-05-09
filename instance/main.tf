data "qiniu_compute_images" "available_official_images" {
  type  = "Official"
  state = "Available"
}

moved {
  from = module.kodo_agent
  to   = module.s3_agent
}

moved {
  from = module.exec_init
  to   = module.s3_exec
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

# 预生成实例标识，用于 s3-agent 和 s3-exec 共享同一个命令通道
resource "random_uuid" "node_id" {}

# 模块 1: 渲染 cloud-init user-data (安装 s3-agent)
module "s3_agent" {
  source = "./modules/s3-agent"

  endpoint_url      = "https://${local.s3_endpoint}"
  bucket            = var.command_bucket
  instance_id       = random_uuid.node_id.result
  access_key_id     = var.qiniu_access_key
  secret_access_key = var.qiniu_secret_key
  region            = var.kodo_region
  poll_interval     = 3
}

resource "qiniu_compute_instance" "node" {
  instance_type          = "ecs.t1.c1m2"
  image_id               = local.ubuntu_image_id
  system_disk_size       = 20
  password               = random_password.instance_password.result
  user_data              = module.s3_agent.rendered
  internet_max_bandwidth = 10
  internet_charge_type   = "Bandwidth"
}

# 等待实例启动和 agent 就绪
resource "time_sleep" "wait_agent_ready" {
  depends_on      = [qiniu_compute_instance.node]
  create_duration = "60s"
}

# 模块 2: 远程执行命令并等待结果
module "s3_exec" {
  source = "./modules/s3-exec"

  endpoint_url      = "https://${local.s3_endpoint}"
  bucket            = var.command_bucket
  instance_id       = random_uuid.node_id.result
  access_key_id     = var.qiniu_access_key
  secret_access_key = var.qiniu_secret_key

  command_type = "shell-script"
  command      = <<-SCRIPT
    apt-get update
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
  SCRIPT
  timeout      = 300

  depends_on = [time_sleep.wait_agent_ready]
}

output "public_ip" {
  description = "实例公网 IP"
  value       = qiniu_compute_instance.node.public_ip_addresses
}

output "exec_result" {
  description = "远程命令执行结果"
  value = {
    command_id  = module.s3_exec.command_id
    exit_code   = module.s3_exec.exit_code
    output      = module.s3_exec.output
    executed_at = module.s3_exec.executed_at
  }
}
