variable "docker_socket_path" {
  type        = string
  description = "Docker socket URI"
}

variable "image_name" {
  type        = string
  description = "Docker image name"
}

variable "container_name" {
  type        = string
  description = "Container name"
}

variable "port_mappings" {
  type = list(object({
    internal = number
    external = number
    protocol = string
  }))
  description = "Port mappings"
}

variable "environment_vars" {
  type        = map(string)
  description = "Environment variables"
}

variable "volume_mounts" {
  type = list(object({
    host_path      = string
    container_path = string
    read_only      = bool
  }))
  description = "Volume mounts"
}
