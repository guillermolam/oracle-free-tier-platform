variable "docker_socket_path" {
  type        = string
  description = "Path to Docker socket (unix:// URI or plain path). For OrbStack: unix:///Users/username/.orbstack/run/docker.sock"
  default     = "unix:///Users/guillermolam/.orbstack/run/docker.sock"

  validation {
    condition     = can(regex("^(unix://|tcp://)", var.docker_socket_path)) || can(regex("^/", var.docker_socket_path))
    error_message = "docker_socket_path must be a unix:// or tcp:// URI, or an absolute path starting with /"
  }
}

variable "image_name" {
  type        = string
  description = "Docker image to use (e.g., alpine:3.18, postgres:16-alpine)"
  default     = "alpine:latest"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._/-]*(@sha256:[a-f0-9]{64})?$", var.image_name))
    error_message = "image_name must follow Docker naming conventions (lowercase, alphanumeric, dots, slashes, dashes). Digest (@sha256:...) is optional"
  }
}

variable "container_name" {
  type        = string
  description = "Name for the container (must be unique per host)"
  default     = "app"

  validation {
    condition     = can(regex("^[a-z0-9_-]{1,63}$", var.container_name))
    error_message = "container_name must be 1-63 characters, lowercase alphanumeric, dash, or underscore only"
  }
}

variable "container_memory_mb" {
  type        = number
  description = "Memory limit in MB (0 = unlimited)"
  default     = 512

  validation {
    condition     = var.container_memory_mb >= 0
    error_message = "container_memory_mb must be >= 0"
  }
}

variable "container_cpu_shares" {
  type        = number
  description = "CPU shares (1024 = 1 CPU, 0 = no limit)"
  default     = 0

  validation {
    condition     = var.container_cpu_shares >= 0
    error_message = "container_cpu_shares must be >= 0"
  }
}

variable "port_mappings" {
  type = list(object({
    internal = number
    external = number
    protocol = string
  }))
  description = "Port mappings from container to host (e.g., {internal = 5432, external = 5432, protocol = \"tcp\"})"
  default     = []

  validation {
    condition = alltrue([
      for p in var.port_mappings : (
        p.internal >= 1 && p.internal <= 65535 &&
        p.external >= 1 && p.external <= 65535 &&
        can(regex("^(tcp|udp)$", p.protocol))
      )
    ])
    error_message = "All port mappings must have internal/external ports (1-65535) and protocol (tcp/udp)"
  }
}

variable "environment_vars" {
  type        = map(string)
  description = "Environment variables to pass to the container"
  default     = {}
}

variable "volume_mounts" {
  type = list(object({
    host_path      = string
    container_path = string
    read_only      = bool
  }))
  description = "Volume mounts from host to container"
  default     = []

  validation {
    condition = alltrue([
      for v in var.volume_mounts : (
        can(regex("^/", v.host_path)) &&
        can(regex("^/", v.container_path))
      )
    ])
    error_message = "All volume paths must be absolute (start with /)"
  }
}

variable "network_mode" {
  type        = string
  description = "Network mode: 'bridge' (custom Docker network), 'host', or 'none'"
  default     = "bridge"

  validation {
    condition     = can(regex("^(bridge|host|none)$", var.network_mode))
    error_message = "network_mode must be 'bridge', 'host', or 'none'"
  }
}

variable "network_name" {
  type        = string
  description = "Name of Docker network to create or use (when network_mode = 'bridge')"
  default     = "app-network"

  validation {
    condition     = can(regex("^[a-z0-9_-]{1,63}$", var.network_name))
    error_message = "network_name must be 1-63 characters, lowercase alphanumeric, dash, or underscore only"
  }
}

variable "network_driver" {
  type        = string
  description = "Docker network driver: 'bridge' or 'overlay'"
  default     = "bridge"

  validation {
    condition     = can(regex("^(bridge|overlay)$", var.network_driver))
    error_message = "network_driver must be 'bridge' or 'overlay'"
  }
}

variable "network_cidr" {
  type        = string
  description = "CIDR block for custom Docker network (e.g., 172.20.0.0/16)"
  default     = ""

  validation {
    condition = (
      var.network_cidr == "" ||
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$", var.network_cidr))
    )
    error_message = "network_cidr must be empty or a valid CIDR block (e.g., 172.20.0.0/16)"
  }
}

variable "restart_policy" {
  type        = string
  description = "Container restart policy: 'no', 'always', 'unless-stopped', 'on-failure'"
  default     = "unless-stopped"

  validation {
    condition     = can(regex("^(no|always|unless-stopped|on-failure)$", var.restart_policy))
    error_message = "restart_policy must be 'no', 'always', 'unless-stopped', or 'on-failure'"
  }
}

variable "privileged" {
  type        = bool
  description = "Run container in privileged mode (dangerous, use with caution)"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags for resource labeling (e.g., {environment = \"lab\", component = \"database\"})"
  default = {
    environment = "lab"
    owner       = "platform"
  }
}
