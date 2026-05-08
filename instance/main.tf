data "qiniu_compute_images" "available_official_images" {
  type  = "Official"
  state = "Available"
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

# 预生成实例标识，用于 kodo-agent 和 remote-exec 共享同一个命令通道
resource "random_uuid" "node_id" {}

# 模块 1: 渲染 cloud-init user-data (安装 kodo-agent)
module "kodo_agent" {
  source = "./modules/kodo-agent"

  endpoint      = local.s3_endpoint
  bucket        = var.command_bucket
  instance_id   = random_uuid.node_id.result
  ak            = var.qiniu_access_key
  sk            = var.qiniu_secret_key
  region        = var.kodo_region
  poll_interval = 3
}

resource "qiniu_compute_instance" "node" {
  instance_type          = "ecs.t1.c1m2"
  image_id               = local.ubuntu_image_id
  system_disk_size       = 20
  password               = random_password.instance_password.result
  user_data              = module.kodo_agent.rendered
  internet_max_bandwidth = 10
  internet_charge_type   = "Bandwidth"
}

# 等待实例启动和 agent 就绪
resource "time_sleep" "wait_agent_ready" {
  depends_on      = [qiniu_compute_instance.node]
  create_duration = "60s"
}

# 模块 2: 远程执行命令并等待结果
module "exec_init" {
  source = "./modules/remote-exec"

  endpoint    = local.s3_endpoint
  bucket      = var.command_bucket
  instance_id = random_uuid.node_id.result
  ak          = var.qiniu_access_key
  sk          = var.qiniu_secret_key

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
    command_id  = module.exec_init.command_id
    exit_code   = module.exec_init.exit_code
    output      = module.exec_init.output
    executed_at = module.exec_init.executed_at
  }
}
