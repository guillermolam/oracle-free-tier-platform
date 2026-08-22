provider "docker" {
  host = "unix:///var/run/docker.sock"
}

run "test_container_creation_defaults" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "app-default"
  }

  assert {
    condition     = docker_container.app.name == "app-default"
    error_message = "Container name must match input"
  }

  assert {
    condition     = docker_container.app.restart_policy == "unless-stopped"
    error_message = "Default restart policy must be unless-stopped"
  }

  assert {
    condition     = docker_container.app.privileged == false
    error_message = "Container must not be privileged by default"
  }
}

run "test_container_with_port_mappings" {
  command = plan

  variables {
    image_name     = "nginx:latest"
    container_name = "nginx-app"
    port_mappings = [
      { internal = 80, external = 8080, protocol = "tcp" },
      { internal = 443, external = 8443, protocol = "tcp" }
    ]
  }

  assert {
    condition     = length(docker_container.app.ports) == 2
    error_message = "Must have 2 port mappings"
  }

  assert {
    condition     = docker_container.app.ports[0].internal == 80
    error_message = "First port internal must be 80"
  }
}

run "test_container_with_env_vars" {
  command = plan

  variables {
    image_name     = "postgres:16-alpine"
    container_name = "postgres-app"
    environment_vars = {
      POSTGRES_DB       = "testdb"
      POSTGRES_PASSWORD = "test_password_123"
    }
  }

  assert {
    condition     = length(docker_container.app.env) == 2
    error_message = "Must have 2 environment variables"
  }
}

run "test_container_memory_limits" {
  command = plan

  variables {
    image_name           = "alpine:latest"
    container_name       = "limited-app"
    container_memory_mb  = 256
    container_cpu_shares = 512
  }

  assert {
    condition     = docker_container.app.memory == 256
    error_message = "Container memory must be 256 MB"
  }

  assert {
    condition     = docker_container.app.cpu_shares == 512
    error_message = "Container CPU shares must be 512"
  }
}

run "test_container_with_restart_policy" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "restart-app"
    restart_policy = "always"
  }

  assert {
    condition     = docker_container.app.restart_policy == "always"
    error_message = "Restart policy must be always"
  }
}

run "test_container_privileged_mode" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "privileged-app"
    privileged     = true
  }

  assert {
    condition     = docker_container.app.privileged == true
    error_message = "Container must be in privileged mode"
  }
}

run "test_container_with_volume_mounts" {
  command = plan

  variables {
    image_name     = "postgres:16-alpine"
    container_name = "postgres-volumes"
    volume_mounts = [
      { host_path = "/data/postgres", container_path = "/var/lib/postgresql/data", read_only = false }
    ]
  }

  assert {
    condition     = length(docker_container.app.volumes) == 1
    error_message = "Must have 1 volume mount"
  }
}

run "test_container_tags" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "tagged-app"
    tags = {
      environment = "production"
      owner       = "platform"
    }
  }

  assert {
    condition     = length(docker_container.app.labels) >= 2
    error_message = "Container must have tags as labels"
  }
}
