resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    organization = var.org
    common_name  = var.domain
  }

  allowed_uses = [
    "key_encipherment",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]

  validity_period_hours = 42000
  is_ca_certificate     = true
}

resource "tls_private_key" "default" {
  for_each = local.hosts
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "default" {
  for_each = local.hosts
  private_key_pem = tls_private_key.default[each.key].private_key_pem

  dns_names = [
    var.domain
  ]

  subject {
    organization = var.org
    common_name  = var.domain
  }
}

# For testing generate certs with differing expriations
resource "tls_locally_signed_cert" "default" {
  for_each = local.hosts
  
  cert_request_pem   = tls_cert_request.default[each.key].cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  # Using the network address to generate predictable results <10 expired <168 expiring everything else okay
  validity_period_hours = each.value.validity < 50 ? 0 : each.value.validity < 168 ? each.value.validity : 365 * 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

