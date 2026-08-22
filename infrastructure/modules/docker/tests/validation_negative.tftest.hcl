provider "docker" {
  host = "unix:///var/run/docker.sock"
}

run "test_invalid_container_name_empty" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = ""
  }

  expect_failures = [var.container_name]
}

run "test_invalid_container_name_too_long" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "this-is-a-very-long-container-name-that-exceeds-the-maximum-allowed-length-of-63-characters-total"
  }

  expect_failures = [var.container_name]
}

run "test_invalid_image_name_empty" {
  command = plan

  variables {
    image_name     = ""
    container_name = "app"
  }

  expect_failures = [var.image_name]
}

run "test_invalid_port_zero" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "app"
    port_mappings = [
      { internal = 0, external = 8080, protocol = "tcp" }
    ]
  }

  expect_failures = [var.port_mappings]
}

run "test_invalid_port_too_high" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "app"
    port_mappings = [
      { internal = 65536, external = 8080, protocol = "tcp" }
    ]
  }

  expect_failures = [var.port_mappings]
}

run "test_invalid_protocol" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "app"
    port_mappings = [
      { internal = 8080, external = 8080, protocol = "invalid" }
    ]
  }

  expect_failures = [var.port_mappings]
}

run "test_invalid_volume_relative_path" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "app"
    volume_mounts = [
      { host_path = "relative/path", container_path = "/data", read_only = false }
    ]
  }

  expect_failures = [var.volume_mounts]
}

run "test_invalid_network_mode" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "app"
    network_mode   = "invalid"
  }

  expect_failures = [var.network_mode]
}

run "test_invalid_network_cidr" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "app"
    network_mode   = "bridge"
    network_cidr   = "invalid-cidr"
  }

  expect_failures = [var.network_cidr]
}

run "test_invalid_restart_policy" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "app"
    restart_policy = "invalid-policy"
  }

  expect_failures = [var.restart_policy]
}

run "test_negative_memory_limit" {
  command = plan

  variables {
    image_name          = "alpine:latest"
    container_name      = "app"
    container_memory_mb = -256
  }

  expect_failures = [var.container_memory_mb]
}

run "test_negative_cpu_shares" {
  command = plan

  variables {
    image_name           = "alpine:latest"
    container_name       = "app"
    container_cpu_shares = -1024
  }

  expect_failures = [var.container_cpu_shares]
}
