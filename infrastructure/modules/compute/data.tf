# Compute module — read-only data sources
#
# Data sources resolve resources created outside this unit. The Talos
# custom image is looked up by display_name + compartment rather than a
# hardcoded OCID so that the same module can be reused across environments.

# Availability domain for placement — Always Free on eu-madrid-1 is single-AD.
# This resolves at plan time regardless of actual quota; capacity errors
# surface during provisioning, not discovery.
data "oci_identity_availability_domain" "ad_1" {
  compartment_id = var.compartment_ocid
  ad_number      = 1
}

# Custom Talos image — looked up by display_name so the caller does not need
# to know the tenancy-specific OCID. A named image must have been imported
# previously (see Infrastructure Pipeline below); the check block below
# catches zero-match at plan time instead of a cryptic index error.
data "oci_core_images" "talos" {
  compartment_id   = var.compartment_ocid
  display_name     = local.talos_image_display_name
  operating_system = "SideroLabs Talos"

  sort_by    = "TIMECREATED"
  sort_order = "DESC"
}

data "oci_core_image" "talos" {
  image_id = data.oci_core_images.talos.images[0].id
}

check "talos_image_found" {
  assert {
    condition     = length(data.oci_core_images.talos.images) > 0
    error_message = "No Talos custom image found matching display_name '${local.talos_image_display_name}' in this compartment. Import it first (see Infrastructure Pipeline)."
  }
}

# micro-nat's own private IP OCID, resolved after creation. 10-network's
# primary discovery path is the freeform-tag lookup described in README.md;
# this output exists as a direct contract for any caller that already has
# this module's outputs in scope.
data "oci_core_private_ips" "micro_nat" {
  subnet_id  = var.subnet_ids.edge
  ip_address = oci_core_instance.micro_nat.private_ip
}
