output "compartment_ocid" {
  value       = oci_identity_compartment.platform.id
  description = "OCID of the platform compartment. Consumed by every downstream module (SPEC-NET-001 Interfaces, SPEC-OCI-002 Interfaces, SPEC-OCI-003 Interfaces)."
}

output "compartment_name" {
  value       = oci_identity_compartment.platform.name
  description = "Name of the platform compartment (for IAM policy statements referencing it by name)."
}

output "tag_namespace_platform" {
  value       = oci_identity_tag_namespace.platform.name
  description = "Name of the 'Platform' defined-tag namespace, for downstream modules building \"Platform.<Key>\" defined_tags references."
}

output "tag_namespace_security" {
  value       = oci_identity_tag_namespace.security.name
  description = "Name of the 'Security' defined-tag namespace, for downstream modules (network) applying Security.TrustZone."
}

output "dynamic_group_ocid" {
  value       = try(oci_identity_dynamic_group.platform_instances[0].id, null)
  description = "OCID of the Dynamic Group matching Talos/Flux-managed instance principals (REQ-OCI-003), or null while var.create_dynamic_group is false. Consumed by I04 (compute) once it exists."
}

output "state_bucket_name" {
  value       = oci_objectstorage_bucket.state.name
  description = "Name of the OpenTofu remote-state bucket. Must match infrastructure/live/common/account.hcl's state_bucket_name."
}

output "state_bucket_namespace" {
  value       = data.oci_objectstorage_namespace.this.namespace
  description = "OCI Object Storage namespace, needed to construct the S3-compatible backend endpoint (infrastructure/live/root.hcl)."
}
