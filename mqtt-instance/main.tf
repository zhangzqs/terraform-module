data "qiniu_compute_images" "available_official_images" {
  type  = "Official"
  state = "Available"
}

locals {
  ubuntu_image_id = one([
    for item in data.qiniu_compute_images.available_official_images.items : item
    if item.os_distribution == "Ubuntu" && item.os_version == "24.04 LTS"
  ]).id

  # Build mqtt_config from individual variables or use provided one
  mqtt_config = var.mqtt_config != null ? var.mqtt_config : {
    broker_host  = var.mqtt_broker_host
    broker_port  = var.mqtt_broker_port
    topic_prefix = var.mqtt_topic_prefix
  }
}

# 0. Generate cryptographic bundle and node_id
module "mqtt_agent_helper" {
  source = "./modules/mqtt-agent-helper"
}

# 1. Generate user_data for cloud-init
module "mqtt_agent_runtime" {
  source = "./modules/mqtt-agent-runtime"

  mqtt_config   = local.mqtt_config
  crypto_bundle = module.mqtt_agent_helper.crypto_bundle
}

# 2. Create compute instance
resource "qiniu_compute_instance" "node" {
  instance_type          = "ecs.t1.c1m2"
  image_id               = local.ubuntu_image_id
  system_disk_size       = 20
  password               = var.root_password
  user_data              = module.mqtt_agent_runtime.rendered
  internet_max_bandwidth = 10
  internet_charge_type   = "Bandwidth"
}

# 3. Wait for Agent heartbeat (confirms Agent is ready)
module "mqtt_agent_heartbeat" {
  source = "./modules/mqtt-agent-heartbeat"

  mqtt_config   = local.mqtt_config
  crypto_bundle = module.mqtt_agent_helper.crypto_bundle
  instance_id   = qiniu_compute_instance.node.id
  timeout       = var.mqtt_command_timeout

  depends_on = [qiniu_compute_instance.node]
}

# 4. Execute command (Agent is confirmed ready via heartbeat)
module "mqtt_agent_exec" {
  source = "./modules/mqtt-agent-exec"

  mqtt_config   = local.mqtt_config
  crypto_bundle = module.mqtt_agent_helper.crypto_bundle
  command_type  = var.command_type
  command       = var.command
  timeout       = var.mqtt_command_timeout

  depends_on = [module.mqtt_agent_heartbeat]
}
