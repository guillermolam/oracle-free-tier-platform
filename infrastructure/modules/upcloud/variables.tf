variable "zone" {
  type        = string
  description = "UpCloud availability zone (e.g., 'es-mad1' for Madrid)"
  default     = "es-mad1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d+$", var.zone))
    error_message = "Zone must be a valid UpCloud zone identifier (e.g., 'es-mad1')."
  }
}

variable "plan" {
  type        = string
  description = "UpCloud server plan (e.g., 'DEV-2xCPU-4GB')"
  default     = "DEV-2xCPU-4GB"
}

variable "disk_size" {
  type        = number
  description = "Storage disk size in GB"
  default     = 60

  validation {
    condition     = var.disk_size >= 10 && var.disk_size <= 4096
    error_message = "Disk size must be between 10 and 4096 GB."
  }
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default = {
    environment = "lab"
    owner       = "platform"
  }
}

variable "firewall_rules" {
  type = object({
    inbound = list(object({
      protocol               = string
      source_port_start      = optional(number)
      source_port_end        = optional(number)
      destination_port_start = number
      destination_port_end   = number
      family                 = optional(string, "IPv4")
      icmp_type              = optional(number)
    }))
    outbound = list(object({
      protocol               = string
      source_port_start      = optional(number)
      source_port_end        = optional(number)
      destination_port_start = number
      destination_port_end   = number
      family                 = optional(string, "IPv4")
      icmp_type              = optional(number)
    }))
  })
  description = "Firewall inbound/outbound rules configuration"
  default = {
    inbound = [
      {
        protocol               = "tcp"
        destination_port_start = 22
        destination_port_end   = 22
        family                 = "IPv4"
        source_port_start      = null
        source_port_end        = null
        icmp_type              = null
      },
      {
        protocol               = "tcp"
        destination_port_start = 80
        destination_port_end   = 80
        family                 = "IPv4"
        source_port_start      = null
        source_port_end        = null
        icmp_type              = null
      },
      {
        protocol               = "tcp"
        destination_port_start = 443
        destination_port_end   = 443
        family                 = "IPv4"
        source_port_start      = null
        source_port_end        = null
        icmp_type              = null
      },
      {
        protocol               = "icmp"
        icmp_type              = 8
        family                 = "IPv4"
        source_port_start      = null
        source_port_end        = null
        destination_port_start = 0
        destination_port_end   = 0
      },
    ]
    outbound = [
      {
        protocol               = "tcp"
        destination_port_start = 80
        destination_port_end   = 80
        family                 = "IPv4"
        source_port_start      = null
        source_port_end        = null
        icmp_type              = null
      },
      {
        protocol               = "tcp"
        destination_port_start = 443
        destination_port_end   = 443
        family                 = "IPv4"
        source_port_start      = null
        source_port_end        = null
        icmp_type              = null
      },
      {
        protocol               = "udp"
        destination_port_start = 53
        destination_port_end   = 53
        family                 = "IPv4"
        source_port_start      = null
        source_port_end        = null
        icmp_type              = null
      },
      {
        protocol               = "icmp"
        icmp_type              = 0
        family                 = "IPv4"
        source_port_start      = null
        source_port_end        = null
        destination_port_start = 0
        destination_port_end   = 0
      },
    ]
  }
}

variable "admin_user" {
  type        = string
  description = "Administrative user account name"
  default     = "ubuntu"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.admin_user))
    error_message = "Admin user must be a valid Linux username."
  }
}

variable "admin_ssh_key" {
  type        = string
  description = "Public SSH key for admin user (e.g., 'ssh-ed25519 AAAA...')"
  default     = ""
  sensitive   = true
}

variable "bootstrap_cidr" {
  type        = string
  description = "CIDR block allowed for bootstrap SSH access (e.g., '203.0.113.0/24')"
  default     = ""
}

variable "ssh_port" {
  type        = number
  description = "SSH port number"
  default     = 22

  validation {
    condition     = var.ssh_port >= 1 && var.ssh_port <= 65535
    error_message = "SSH port must be between 1 and 65535."
  }
}

variable "hostname" {
  type        = string
  description = "Server hostname"
  default     = "k8s-node"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.hostname))
    error_message = "Hostname must be valid (lowercase alphanumeric and hyphens only)."
  }
}

variable "network_name" {
  type        = string
  description = "UpCloud network name"
  default     = "k8s-cluster-network"
}

variable "network_cidr" {
  type        = string
  description = "Network CIDR block"
  default     = "10.0.0.0/24"
}

variable "router_name" {
  type        = string
  description = "UpCloud router name"
  default     = "k8s-cluster-router"
}

variable "storage_tier" {
  type        = string
  description = "Storage tier ('standard' or 'maxiops')"
  default     = "standard"

  validation {
    condition     = contains(["standard", "maxiops"], var.storage_tier)
    error_message = "Storage tier must be 'standard' or 'maxiops'."
  }
}

variable "metadata_enabled" {
  type        = bool
  description = "Enable cloud-init metadata service"
  default     = true
}

variable "user_data" {
  type        = string
  description = "Cloud-init user data script"
  default     = ""
}
