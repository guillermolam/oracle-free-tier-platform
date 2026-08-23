provider "docker" {
  host = "unix:///var/run/docker.sock"
}

run "test_full_postgres_stack" {
  command = plan

  variables {
    image_name     = "postgres:16-alpine"
    container_name = "postgres-prod"

    port_mappings = [
      { internal = 5432, external = 5432, protocol = "tcp" }
    ]

    environment_vars = {
      POSTGRES_DB       = "production"
      POSTGRES_PASSWORD = "test_prod_pass_abc"
      POSTGRES_USER     = "admin"
    }

    volume_mounts = [
      { host_path = "/var/lib/postgresql", container_path = "/var/lib/postgresql/data", read_only = false }
    ]

    network_name = "postgres-network"
    network_cidr = "172.21.0.0/16"

    container_memory_mb  = 1024
    container_cpu_shares = 2048

    restart_policy = "unless-stopped"

    tags = {
      environment = "production"
      component   = "database"
      owner       = "platform"
    }
  }

  assert {
    condition     = docker_container.app.name == "postgres-prod"
    error_message = "Container name must match"
  }

  assert {
    condition     = length(docker_container.app.ports) == 1
    error_message = "Must have 1 port mapping"
  }

  assert {
    condition     = length(docker_container.app.env) == 3
    error_message = "Must have 3 environment variables"
  }

  assert {
    condition     = length(docker_container.app.volumes) == 1
    error_message = "Must have 1 volume mount"
  }

  assert {
    condition     = docker_container.app.memory == 1024
    error_message = "Memory must be 1024 MB"
  }
}

run "test_multiple_port_mappings" {
  command = plan

  variables {
    image_name     = "nginx:latest"
    container_name = "nginx-multi"

    port_mappings = [
      { internal = 80, external = 8080, protocol = "tcp" },
      { internal = 443, external = 8443, protocol = "tcp" },
      { internal = 8000, external = 8000, protocol = "tcp" }
    ]
  }

  assert {
    condition     = length(docker_container.app.ports) == 3
    error_message = "Must have 3 port mappings"
  }

  assert {
    condition     = contains([for p in docker_container.app.ports : p.internal], 80)
    error_message = "Port 80 must be in mappings"
  }

  assert {
    condition     = contains([for p in docker_container.app.ports : p.internal], 443)
    error_message = "Port 443 must be in mappings"
  }
}

run "test_multiple_volume_mounts" {
  command = plan

  variables {
    image_name     = "postgres:16-alpine"
    container_name = "postgres-volumes"

    volume_mounts = [
      { host_path = "/data/postgres", container_path = "/var/lib/postgresql/data", read_only = false },
      { host_path = "/data/backup", container_path = "/backup", read_only = false },
      { host_path = "/etc/postgresql", container_path = "/etc/postgresql", read_only = true }
    ]
  }

  assert {
    condition     = length(docker_container.app.volumes) == 3
    error_message = "Must have 3 volume mounts"
  }
}

run "test_minimal_configuration" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "minimal"
  }

  assert {
    condition     = docker_container.app.name == "minimal"
    error_message = "Minimal config must still create container"
  }

  assert {
    condition     = docker_container.app.restart_policy == "unless-stopped"
    error_message = "Minimal config must use default restart policy"
  }

  assert {
    condition     = docker_container.app.privileged == false
    error_message = "Minimal config must not be privileged"
  }

  assert {
    condition     = length(docker_container.app.ports) == 0
    error_message = "Minimal config must have no port mappings"
  }

  assert {
    condition     = length(docker_container.app.volumes) == 0
    error_message = "Minimal config must have no volume mounts"
  }
}

run "test_custom_socket_path" {
  command = plan

  variables {
    docker_socket_path = "unix:///Users/test/.orbstack/run/docker.sock"
    image_name         = "alpine:latest"
    container_name     = "custom-socket"
  }

  assert {
    condition     = docker_container.app.name == "custom-socket"
    error_message = "Custom socket path must still create container"
  }
}

run "test_network_with_multiple_modes" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "bridge-explicit"
    network_mode   = "bridge"
    network_name   = "bridge-network"
  }

  assert {
    condition     = docker_network.app[0].name == "bridge-network"
    error_message = "Bridge network must be created"
  }
}

run "test_empty_environment_vars" {
  command = plan

  variables {
    image_name       = "alpine:latest"
    container_name   = "no-env"
    environment_vars = {}
  }

  assert {
    condition     = length(docker_container.app.env) == 0
    error_message = "Empty environment vars must result in empty env list"
  }
}

run "test_empty_port_mappings" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "no-ports"
    port_mappings  = []
  }

  assert {
    condition     = length(docker_container.app.ports) == 0
    error_message = "Empty port mappings must result in no ports"
  }
}
