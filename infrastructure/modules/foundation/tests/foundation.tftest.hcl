# Positive tests -- module contract at plan time, no real OCI credentials
# required (mock_provider stands in for the real provider).

mock_provider "oci" {}

variables {
  tenancy_ocid      = "ocid1.tenancy.oc1..aaaaaaaaexampleexampleexampleexampleexampleexampleexampleaaaa"
  environment       = "lab"
  ci_group_name     = "platform-ci"
  admin_group_name  = "platform-admins"
  state_bucket_name = "oracle-free-tier-platform-tfstate"
}

run "compartment_has_expected_defaults" {
  command = plan

  assert {
    condition     = oci_identity_compartment.platform.name == "platform"
    error_message = "compartment name should default to 'platform'"
  }

  assert {
    condition     = oci_identity_compartment.platform.enable_delete == false
    error_message = "REQ-OCI-001/rollback: enable_delete must stay explicitly false"
  }
}

run "state_bucket_is_private_and_versioned" {
  command = plan

  assert {
    condition     = oci_objectstorage_bucket.state.access_type == "NoPublicAccess"
    error_message = "REQ-OCI-005 Security Requirements: state bucket must not be publicly accessible"
  }

  assert {
    condition     = oci_objectstorage_bucket.state.versioning == "Enabled"
    error_message = "REQ-OCI-005: state bucket must have versioning enabled"
  }
}

run "ci_policy_has_no_tenancy_scope" {
  command = plan

  assert {
    condition     = !anytrue([for s in oci_identity_policy.ci.statements : strcontains(s, "in tenancy")])
    error_message = "REQ-OCI-002: no CI policy statement may target tenancy scope"
  }
}

run "ci_policy_does_not_grant_all_resources" {
  command = plan

  assert {
    condition     = !anytrue([for s in oci_identity_policy.ci.statements : strcontains(s, "all-resources")])
    error_message = "REQ-OCI-002/least-privilege: CI policy must enumerate specific resource-type families, never all-resources -- that would silently broaden CI visibility as new resource types are added elsewhere"
  }
}

run "admin_policy_has_no_tenancy_scope" {
  command = plan

  assert {
    condition     = !anytrue([for s in oci_identity_policy.admin.statements : strcontains(s, "in tenancy")])
    error_message = "REQ-OCI-002: no admin policy statement may target tenancy scope"
  }
}

run "dynamic_group_deferred_by_default" {
  command = plan

  assert {
    condition     = length(oci_identity_dynamic_group.platform_instances) == 0
    error_message = "REQ-OCI-003's dynamic group must be deferred (create_dynamic_group defaults to false) until M2 compute exists to match -- see variables.tf"
  }
}

run "dynamic_group_matches_on_compartment_when_enabled" {
  command = plan

  variables {
    create_dynamic_group = true
  }

  assert {
    condition     = can(regex("instance.compartment.id", oci_identity_dynamic_group.platform_instances[0].matching_rule))
    error_message = "REQ-OCI-003: dynamic group must match on instance.compartment.id when created"
  }
}

run "defined_tags_taxonomy_has_four_key_resources_but_three_applied_values" {
  command = plan

  # 4 oci_identity_tag resources define the taxonomy (Environment, System,
  # ManagedBy, TrustZone), but local.foundation_defined_tags -- the map
  # actually applied to this module's own resources -- only populates 3:
  # TrustZone is taxonomy-only here, with no value until the network
  # module's zone-scoped resources consume it.
  assert {
    condition     = oci_identity_tag.security_trust_zone.name == "TrustZone"
    error_message = "the 4th tag resource (Security.TrustZone) should exist in the taxonomy even though this module applies no value for it"
  }

  assert {
    condition     = length(local.foundation_defined_tags) == 3
    error_message = "foundation resources should carry exactly 3 defined-tag values (Environment, System, ManagedBy)"
  }
}
