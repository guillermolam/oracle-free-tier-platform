# REQ-OCI-004: Defined Tags. This module defines the TAXONOMY (namespaces
# + keys); it does not set every value for every future resource type --
# downstream modules (network, kms, logging-monitoring) own their own
# resource-specific tag values, per infrastructure/README.md#tagging-contract.
#
# REQ-OCI-004's literal example ("platform=oracle-free-tier,
# environment=<lab|staging|prod>") uses bare lowercase keys, which OCI's
# Defined Tags data model can't express directly (a Defined Tag always
# needs a Namespace.Key structure -- there is no namespace-less defined
# tag). This module maps that example onto Platform.System (value:
# var.platform_name) and Platform.Environment (value: var.environment) --
# an explicit implementation decision, not a silent reinterpretation.

resource "oci_identity_tag_namespace" "platform" {
  compartment_id = oci_identity_compartment.platform.id
  name           = "Platform"
  description    = "Platform-wide defined tags (REQ-OCI-004)."
}

resource "oci_identity_tag" "platform_environment" {
  tag_namespace_id = oci_identity_tag_namespace.platform.id
  name             = "Environment"
  description      = "Deployment environment (lab|staging|prod)."
  is_cost_tracking = false
}

resource "oci_identity_tag" "platform_system" {
  tag_namespace_id = oci_identity_tag_namespace.platform.id
  name             = "System"
  description      = "Owning platform/system identifier (REQ-OCI-004's 'platform=' example)."
  is_cost_tracking = false
}

resource "oci_identity_tag" "platform_managed_by" {
  tag_namespace_id = oci_identity_tag_namespace.platform.id
  name             = "ManagedBy"
  description      = "Tooling that manages this resource (always 'opentofu' in this repo)."
  is_cost_tracking = false
}

# Security.TrustZone is defined here (taxonomy) but has no value on any
# resource THIS module creates -- none of foundation's resources are
# zone-scoped. The network module (10-network) is the first consumer.
resource "oci_identity_tag_namespace" "security" {
  compartment_id = oci_identity_compartment.platform.id
  name           = "Security"
  description    = "Security-relevant classification tags."
}

resource "oci_identity_tag" "security_trust_zone" {
  tag_namespace_id = oci_identity_tag_namespace.security.id
  name             = "TrustZone"
  description      = "Trust zone this resource belongs to (edge|management|workload|data|n/a)."
  is_cost_tracking = false
}

locals {
  # Applied to every resource this module itself creates.
  foundation_defined_tags = {
    "${oci_identity_tag_namespace.platform.name}.${oci_identity_tag.platform_environment.name}" = var.environment
    "${oci_identity_tag_namespace.platform.name}.${oci_identity_tag.platform_system.name}"      = var.platform_name
    "${oci_identity_tag_namespace.platform.name}.${oci_identity_tag.platform_managed_by.name}"  = "opentofu"
  }
}
