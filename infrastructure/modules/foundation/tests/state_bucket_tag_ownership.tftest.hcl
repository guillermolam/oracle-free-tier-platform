# Regression tests for state_backend.tf's ignore_changes scope (the
# Oracle-Tags.CreatedBy/CreatedOn lifecycle exception). See state_backend.tf's
# comment for why the exception exists.
#
# What this file CANNOT test: OpenTofu's mock/override system explicitly
# refuses to fake a config-set attribute (confirmed empirically -- attempting
# `override_resource { values = { defined_tags = ... } }` against this
# resource fails with OpenTofu's own error "Invalid mock/override field
# defined_tags: The field is ignored since overriding configuration values is
# not allowed"). Since defined_tags is set directly in state_backend.tf
# (`defined_tags = local.foundation_defined_tags`), there is no way to
# simulate "OCI injected extra keys behind OpenTofu's back" through
# mock_provider -- that would require a real provider's independent Read,
# which mock_provider does not perform. The actual drift-suppression
# behavior (Oracle-Tags ignored, Platform.*/Security.* still tracked) was
# instead validated empirically against the live tenancy: a real
# post-migration plan showed OpenTofu trying to null out both Oracle-Tags
# keys before this fix, and 0 changes after it.
#
# What this file DOES prove: the module's own intended tag set is exactly
# what we think it is -- 3 keys, none of them under the Oracle-Tags
# namespace this module doesn't own -- so the ignore_changes exception has
# nothing of ours left to accidentally swallow.

mock_provider "oci" {}

variables {
  tenancy_ocid      = "ocid1.tenancy.oc1..aaaaaaaaexampleexampleexampleexampleexampleexampleexampleaaaa"
  environment       = "lab"
  state_bucket_name = "oracle-free-tier-platform-tfstate"
}

run "bucket_defined_tags_contain_no_oracle_managed_keys" {
  command = plan

  assert {
    condition     = !anytrue([for k in keys(oci_objectstorage_bucket.state.defined_tags) : strcontains(k, "Oracle-Tags")])
    error_message = "this module must never itself declare an Oracle-Tags.* key -- state_backend.tf's ignore_changes exists precisely because OCI injects these, not this module"
  }

  assert {
    condition     = length(oci_objectstorage_bucket.state.defined_tags) == 3
    error_message = "the state bucket's own managed defined_tags must stay exactly Platform.Environment/System/ManagedBy -- any growth here should be a deliberate change, reviewed against the ignore_changes scope in the same PR"
  }
}

run "platform_tag_value_reflects_environment_input" {
  command = plan

  variables {
    environment = "staging"
  }

  assert {
    condition     = oci_objectstorage_bucket.state.defined_tags["Platform.Environment"] == "staging"
    error_message = "Platform.Environment must still be fully config-driven -- proves this module's own tags are not accidentally inside the ignore_changes scope"
  }
}
