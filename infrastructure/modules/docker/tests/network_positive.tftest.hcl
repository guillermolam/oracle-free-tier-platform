provider "docker" {
  host = "unix:///var/run/docker.sock"
}

run "test_bridge_network_creation" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "bridge-app"
    network_mode   = "bridge"
    network_name   = "app-network"
  }

  assert {
    condition     = docker_network.app[0].name == "app-network"
    error_message = "Network name must be app-network"
  }

  assert {
    condition     = docker_network.app[0].driver == "bridge"
    error_message = "Network driver must be bridge"
  }
}

run "test_bridge_network_with_custom_cidr" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "cidr-app"
    network_mode   = "bridge"
    network_name   = "custom-network"
    network_cidr   = "172.20.0.0/16"
  }

  assert {
    condition     = length(docker_network.app) > 0
    error_message = "Network must be created for bridge mode"
  }
}

run "test_host_network_mode" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "host-app"
    network_mode   = "host"
  }

  assert {
    condition     = length(docker_network.app) == 0
    error_message = "Network must not be created for host mode"
  }

  assert {
    condition     = docker_container.app.network_mode == "host"
    error_message = "Container network mode must be host"
  }
}

run "test_none_network_mode" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "none-app"
    network_mode   = "none"
  }

  assert {
    condition     = length(docker_network.app) == 0
    error_message = "Network must not be created for none mode"
  }

  assert {
    condition     = docker_container.app.network_mode == "none"
    error_message = "Container network mode must be none"
  }
}

run "test_overlay_network_driver" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "overlay-app"
    network_mode   = "bridge"
    network_driver = "overlay"
  }

  assert {
    condition     = docker_network.app[0].driver == "overlay"
    error_message = "Network driver must be overlay"
  }
}

run "test_network_with_container_labels" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "labeled-app"
    network_mode   = "bridge"
    network_name   = "labeled-network"
    tags = {
      environment = "test"
      owner       = "platform"
    }
  }

  assert {
    condition     = length(docker_network.app[0].labels) >= 2
    error_message = "Network must have labels from tags"
  }
}
