terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.1"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

locals {
  project_name = var.project_name
  ipaddrs      = jsondecode(file("${path.module}/../assets/ips.json"))
  services     = [for s, v in local.ipaddrs : s]
  # It would make more sense to modify ips.json to be a more useful structure
  # but I left things this way to demonstrate my understanding of how to 
  # manipulate data directly in terraform.
  hosts = {
    for ipv4, service in transpose(local.ipaddrs) :
    join("-", [service[0], replace(ipv4, ".", "-")]) => {
      "network" : "${local.project_name}_${service[0]}"
      "ipv4" : ipv4
      "port" : service[0] == "callisto" ? 8000 : 4000
      "service" : service[0]
      "validity" : split(".", ipv4)[3]
    }
  }
}

# Create bridge networks for each service.
resource "docker_network" "network" {
  for_each = {
    europa   = "10.10.6.0/24"
    callisto = "10.10.8.0/24"
    devops   = "10.10.4.0/24"
  }
  name   = "${local.project_name}_${each.key}"
  driver = "bridge"
  ipam_config {
    subnet = each.value
  }
}

# Build bastion docker image.
resource "docker_image" "bastion" {
  name = "bastion"
  build {
    context = "${path.module}/../docker/bastion"
    tag     = ["local/bastion:latest"]
  }

  # Trigger rebuild if files in bastion directory change
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "../docker/bastion/*") : filesha1(f)]))
  }
}

# Create statsd container
resource "docker_container" "bastion" {
  name     = "${local.project_name}_bastion"
  hostname = "${local.project_name}_bastion"
  image    = docker_image.bastion.image_id
  env = [
    "IPSJSON=/ips.json",
    "STATSD_IPPORT=10.10.2.14:8125",
    #"WEBHOOK_URL=https://hooks.slack.com/services/",
  ]

  dynamic "networks_advanced" {
    for_each = docker_network.network
    content {
      name = networks_advanced.value.id
    }
  }
  upload {
    file    = "/ips.json"
    content = jsonencode(local.ipaddrs)
  }
  depends_on = [
    docker_container.service
  ]
}

resource "docker_container" "statsd" {
  name     = "${local.project_name}_statsd"
  hostname = "${local.project_name}_statsd"
  image    = "statsd/statsd"

  networks_advanced {
    name         = docker_network.network["devops"].id
    ipv4_address = "10.10.4.14"
  }

  ports {
    internal = 8125
    external = 8125
    protocol = "udp"
  }

  ports {
    internal = 8126
    external = 8126
  }
}
