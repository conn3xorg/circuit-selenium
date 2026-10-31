output "grid_url" {
  description = "Address to give a RemoteWebDriver, reachable from wherever listen_address allows."
  value       = "http://${var.listen_address}:${var.port}"
}

output "services" {
  description = "The systemd service of each container, by container name."
  value       = module.podman.services
}

output "images" {
  description = "The image each container runs, with its tag and digest."
  value       = merge({ selenium-hub = local.hub_image }, { for n, c in local.nodes : n => c.image })
}
