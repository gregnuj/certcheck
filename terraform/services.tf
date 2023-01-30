# Build per service docker images.
resource "docker_image" "image" {
  for_each = toset(local.services)
  name = each.key
  build {
    context = "${path.module}/../docker/services"
    tag     = ["local/${each.key}:latest"]
  }

  # Trigger rebuild if files in services directory change
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "../docker/services/*") : filesha1(f)]))
  }
}

# Create containers from hosts map
resource "docker_container" "service" {
  for_each = local.hosts

  name  = "${local.project_name}_${each.key}"
  hostname = each.key
  image = docker_image.image[each.value.service].image_id
  env = [
    "HTTPS_PORT=${each.value.port}"
  ]

  # Using the service name in the network creation allows us to map it here.
  networks_advanced {
    name = docker_network.network[each.value.service].id
    ipv4_address = each.value.ipv4
  }

  # Will choose a random(ish) external port to map to
  ports {
    internal = each.value.port
  }

  # Upload the keyfiles to container
  upload {
    file = "/app/.ssl/ca.crt"
    content = tls_self_signed_cert.ca.cert_pem
  }
  upload {
    file = "/app/.ssl/default.key"
    content = tls_private_key.default[each.key].private_key_pem
  }
  upload {
    file = "/app/.ssl/default.crt"
    content = tls_locally_signed_cert.default[each.key].cert_pem
  }
}