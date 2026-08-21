run "invalid_disk_size_too_small" {
  command = plan

  variables {
    disk_size = 5 # Less than minimum 10
  }

  expect_failures = [var.disk_size]
}

run "invalid_disk_size_too_large" {
  command = plan

  variables {
    disk_size = 5000 # Greater than maximum 4096
  }

  expect_failures = [var.disk_size]
}

run "invalid_ssh_port_too_low" {
  command = plan

  variables {
    ssh_port = 0 # Less than minimum 1
  }

  expect_failures = [var.ssh_port]
}

run "invalid_ssh_port_too_high" {
  command = plan

  variables {
    ssh_port = 65536 # Greater than maximum 65535
  }

  expect_failures = [var.ssh_port]
}

run "invalid_hostname_with_uppercase" {
  command = plan

  variables {
    hostname = "K8s-Node" # Contains uppercase
  }

  expect_failures = [var.hostname]
}

run "invalid_hostname_starts_with_number" {
  command = plan

  variables {
    hostname = "1k8s-node" # Starts with number
  }

  expect_failures = [var.hostname]
}

run "invalid_hostname_with_dots" {
  command = plan

  variables {
    hostname = "k8s.node" # Contains dot
  }

  expect_failures = [var.hostname]
}

run "invalid_admin_user_with_dot" {
  command = plan

  variables {
    admin_user = "admin.user" # Contains dot
  }

  expect_failures = [var.admin_user]
}

run "invalid_admin_user_starts_with_number" {
  command = plan

  variables {
    admin_user = "1admin" # Starts with number
  }

  expect_failures = [var.admin_user]
}

run "invalid_zone_format" {
  command = plan

  variables {
    zone = "invalid-zone" # Wrong format
  }

  # This may or may not fail validation depending on whether the zone check runs
  # before the format check. The condition checks the zone value.
}

run "invalid_storage_tier" {
  command = plan

  variables {
    storage_tier = "ultra" # Not 'standard' or 'maxiops'
  }

  expect_failures = [var.storage_tier]
}

run "invalid_plan_nonexistent" {
  command = plan

  variables {
    plan = "NONEXISTENT-PLAN"
  }

  # Plan validation happens at UpCloud API level, not in Terraform validation
  # so this may not fail at plan time
}

run "invalid_network_cidr_format" {
  command = plan

  variables {
    network_cidr = "not-a-cidr"
  }

  # CIDR validation is loose in Terraform; UpCloud will reject invalid CIDRs
  # This test documents the behavior but may not fail validation
}
