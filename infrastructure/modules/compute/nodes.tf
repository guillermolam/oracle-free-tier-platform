# Compute module — Talos compute nodes
#
# All Talos nodes boot in maintenance/no-secret mode (REQ-COMP-007).
# Machine-config and tokens are applied later via talosctl over the fabric.
#
# Nodes are created via for_each keyed on local.node_map. Each node's
# subnet is determined by its zone mapping (node_map.zone -> zone_subnet_ids).

resource "oci_core_instance" "talos_node" {
  for_each            = local.node_map
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domain.ad_1.name
  display_name        = "${local.name_prefix}-${each.key}"
  shape               = each.value.shape

  shape_config {
    ocpus         = each.value.ocpus
    memory_in_gbs = each.value.memory_in_gbs
  }

  # Image: custom imported Talos qcow2 (BYOI — OCI has no official Talos image).
  # The image was imported into this tenancy via oci_image_import_from_object_storage.
  source_details {
    source_type             = "image"
    source_id               = data.oci_core_image.talos.id
    boot_volume_size_in_gbs = each.value.boot_volume_size_in_gbs
    boot_volume_vpus_per_gb = each.value.boot_volume_vpus_per_gb
  }

  # Placement: control-plane → Management zone; workers → Workload zone.
  # No public IP on Talos nodes. REQ-COMP-005.
  create_vnic_details {
    subnet_id        = local.zone_subnet_ids[each.value.zone]
    display_name     = "${local.name_prefix}-${each.key}-vnic"
    assign_public_ip = false
  }

  # Metadata: empty — no SSH key, no secrets. REQ-COMP-006/007.
  # Talos boots into maintenance mode and waits for external configuration.
  metadata = {
    ssh_authorized_keys = ""
    user_data           = ""
  }

  # Legacy instance-metadata-service v1 endpoint (CKV_OCI_5): Talos only
  # needs IMDS v2, so the legacy endpoint stays disabled.
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  # In-transit encryption (CKV_OCI_4) requires a paravirtualized boot-volume
  # attachment; set at create time here (the launch_options copy below only
  # applies on update per the provider's own field description).
  is_pv_encryption_in_transit_enabled = true

  # Paravirtualized + UEFI_64 firmware: required for A1.Flex boot compatibility
  # (SPEC-COMP-001 Constraints — pinned image MUST verify-boot PARAVIRTUALIZED,
  # UEFI_64). boot_volume_type must be PARAVIRTUALIZED for
  # is_pv_encryption_in_transit_enabled to take effect.
  # See https://docs.oracle.com/en-us/iaas/Content/Compute/References/custom-image-import.htm
  launch_options {
    firmware                            = "UEFI_64"
    network_type                        = "PARAVIRTUALIZED"
    boot_volume_type                    = "PARAVIRTUALIZED"
    is_pv_encryption_in_transit_enabled = true
  }

  defined_tags = {}
  freeform_tags = merge(local.common_tags, {
    "Platform.Role" = each.value.role
    "Platform.Zone" = each.value.zone
    "Platform.IsCP" = tostring(each.value.is_control_plane)
    "Talos.Version" = var.talos_version
  })

  lifecycle {
    ignore_changes = [
      # OCI-defined tags.
      defined_tags,
      # Metadata changes during bootstrap (talosctl apply-config modifies state).
      metadata,
    ]
  }

  # Disk attachments: each node gets a 50GB boot volume + future storage volumes.
  # Storage volumes are attached in I15/SPEC-STOR-* (Longhorn/SeaweedFS).

}
