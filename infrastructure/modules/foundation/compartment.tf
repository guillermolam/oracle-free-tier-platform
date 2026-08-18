# REQ-OCI-001: dedicated platform compartment, child of the tenancy root.
# Every other resource in this module (and every downstream module) is
# provisioned inside this compartment, never directly in the tenancy root.

resource "oci_identity_compartment" "platform" {
  compartment_id = var.tenancy_ocid
  name           = var.compartment_name
  description    = var.compartment_description

  # Explicit, not relying on the provider's own default (also false):
  # SPEC-OCI-001's Rollback/Recovery section is explicit that `tofu
  # destroy` is unsafe once anything depends on this compartment.
  # enable_delete=false means `tofu destroy`/removing this resource block
  # detaches Terraform's management without deleting the real compartment.
  enable_delete = false

  # freeform_tags only, deliberately: defined_tags here would have to
  # reference the tag namespaces in tags.tf, which are themselves created
  # INSIDE this compartment (tag_namespace.compartment_id =
  # oci_identity_compartment.platform.id) -- referencing them back on this
  # resource would be a circular dependency. Every resource created AFTER
  # the compartment (state bucket, etc.) gets local.foundation_defined_tags.
  freeform_tags = {
    "provisioned-by" = "opentofu"
  }

  lifecycle {
    prevent_destroy = true
  }
}
