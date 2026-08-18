# Negative tests -- every one of these MUST fail. Validation blocks run
# before any provider call, so these don't need mock_provider/credentials
# either, but it's harmless to keep it for consistency with the positive
# suite.

mock_provider "oci" {}

variables {
  tenancy_ocid      = "ocid1.tenancy.oc1..aaaaaaaaexampleexampleexampleexampleexampleexampleexampleaaaa"
  environment       = "lab"
  state_bucket_name = "oracle-free-tier-platform-tfstate"
}

run "invalid_environment_rejected" {
  command = plan

  variables {
    environment = "production" # not one of lab|staging|prod
  }

  expect_failures = [var.environment]
}

run "empty_ci_group_name_rejected_when_policies_enabled" {
  command = plan

  variables {
    create_iam_policies = true
    ci_group_name       = ""
    admin_group_name    = "platform-admins"
  }

  expect_failures = [var.ci_group_name]
}

run "empty_admin_group_name_rejected_when_policies_enabled" {
  command = plan

  variables {
    create_iam_policies = true
    ci_group_name       = "platform-ci"
    admin_group_name    = "   " # whitespace-only, trimspace() catches this
  }

  expect_failures = [var.admin_group_name]
}

run "invalid_bucket_name_rejected" {
  command = plan

  variables {
    state_bucket_name = "UPPERCASE_Not_Allowed"
  }

  expect_failures = [var.state_bucket_name]
}

run "invalid_tenancy_ocid_rejected" {
  command = plan

  variables {
    tenancy_ocid = "not-an-ocid"
  }

  expect_failures = [var.tenancy_ocid]
}
