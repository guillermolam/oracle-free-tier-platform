provider "docker" {
  host = "unix:///var/run/docker.sock"
}

run "test_alpine_image_pull" {
  command = plan

  variables {
    image_name     = "alpine:latest"
    container_name = "alpine-test"
  }

  assert {
    condition     = docker_image.app.name == "alpine:latest"
    error_message = "Image name must be alpine:latest"
  }

  assert {
    condition     = length(docker_image.app.id) > 0
    error_message = "Image ID must be non-empty"
  }
}

run "test_postgres_image_pull" {
  command = plan

  variables {
    image_name     = "postgres:16-alpine"
    container_name = "postgres-test"
  }

  assert {
    condition     = docker_image.app.name == "postgres:16-alpine"
    error_message = "Image name must be postgres:16-alpine"
  }
}

run "test_custom_image_registry" {
  command = plan

  variables {
    image_name     = "ghcr.io/example/custom:v1.0"
    container_name = "custom-test"
  }

  assert {
    condition     = can(regex("ghcr.io", docker_image.app.name))
    error_message = "Image must support custom registries"
  }
}
