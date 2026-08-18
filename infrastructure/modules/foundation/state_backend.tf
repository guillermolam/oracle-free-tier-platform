# REQ-OCI-005: dedicated, versioned OCI Object Storage bucket for OpenTofu
# remote state. Deliberately separate from any future backup bucket
# (I19/M9, ARCH-SVC-BACKUP-BUCKET) -- state has fundamentally different
# confidentiality/retention/access/lifecycle requirements than backup
# data, and SPEC-OCI-001 does not require them to be the same resource.
# Oracle-managed encryption satisfies REQ-OCI-005 -- SPEC-OCI-002's own
# Non-Goals section confirms customer-managed (KMS) encryption on this
# bucket is an optional follow-on, not required.

data "oci_objectstorage_namespace" "this" {
  compartment_id = var.tenancy_ocid
}

# Per SPEC-OCI-002's Non-Goals: customer-managed (KMS) encryption on this
# bucket is an optional follow-on, not required -- REQ-OCI-005 is
# satisfied by OCI's default Oracle-managed encryption. Checkov's
# CKV_OCI_9 ("Ensure OCI Object Storage is encrypted with Customer
# Managed Key") is skipped at the workflow level for this reason -- see
# .github/workflows/validate.yml's checkov step -- an inline
# #checkov:skip comment here did not reliably suppress the finding when
# the resource is reached through a module call (examples/minimal), so
# the workflow-level --skip-check is the verified-working mechanism.
resource "oci_objectstorage_bucket" "state" {
  compartment_id = oci_identity_compartment.platform.id
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = var.state_bucket_name

  versioning = "Enabled"

  # Explicit, not relying on the provider default: SPEC-OCI-001's Security
  # Requirements section is explicit that this bucket "must not be
  # publicly accessible" -- also Checkov-enforced (validate.yml,
  # soft_fail: false) as a second, independent layer.
  access_type = "NoPublicAccess"

  # CKV_OCI_7 (Checkov): cheap, sensible, no Spec excludes it -- feeds
  # I16 observability later (state-bucket change events) and costs
  # nothing extra on Free Tier.
  object_events_enabled = true

  freeform_tags = { "provisioned-by" = "opentofu", "purpose" = "opentofu-state" }
  defined_tags  = local.foundation_defined_tags

  lifecycle {
    prevent_destroy = true
  }
}
