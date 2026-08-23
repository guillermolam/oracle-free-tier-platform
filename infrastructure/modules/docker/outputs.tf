output "container_id" {
  value       = docker_container.app.id
  description = "Full container ID"
}

output "container_name" {
  value       = docker_container.app.name
  description = "Container name"
}

output "image_id" {
  value       = docker_image.app.id
  description = "Docker image ID"
}

output "image_repo_digest" {
  value       = try(docker_image.app.repo_digest, "")
  description = "Image repository digest (if available)"
}

output "network_id" {
  value       = try(docker_network.app[0].id, "")
  description = "Docker network ID (if created)"
}

output "network_name" {
  value       = try(docker_network.app[0].name, "")
  description = "Docker network name (if created)"
}

output "container_ports" {
  value = [
    for p in docker_container.app.ports :
    {
      internal = p.internal
      external = p.external
      protocol = p.protocol
    }
  ]
  description = "Exposed port mappings"
}

output "container_status" {
  value       = try(docker_container.app.exit_code, 0)
  description = "Container exit code (0 = running)"
}
