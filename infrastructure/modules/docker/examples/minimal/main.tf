terraform {
  required_version = ">= 1.12.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {
  host = var.docker_socket_path
}

module "example_container" {
  source = "../../"

  image_name     = var.image_name
  container_name = var.container_name

  port_mappings = var.port_mappings

  environment_vars = var.environment_vars

  volume_mounts = var.volume_mounts

  tags = {
    environment = "lab"
    example     = "minimal"
  }
}

output "container_id" {
  value       = module.example_container.container_id
  description = "ID of the created container"
}

output "network_name" {
  value       = module.example_container.network_name
  description = "Name of the created network"
}
