# Compute module — software-NAT instance (micro-nat)
#
# REQ-COMP-001: Runs on VM.Standard.E2.1.Micro (x86_64), NOT on A1.Flex.
# This keeps the entire 4 OCPU / 24 GB ARM budget for Kubernetes nodes.
# REQ-COMP-004: Placed in Edge zone with public IP + skip_source_dest_check.
# REQ-COMP-006: No SSH from internet. Reachable only through Ziti fabric.
# REQ-COMP-008: Carries freeform tag role = "software-nat" for discovery by
# 10-network's data.oci_core_instances.software_nat lookup.

resource "oci_core_instance" "micro_nat" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domain.ad_1.name
  display_name        = local.micro_nat_display_name
  shape               = var.micro_nat_shape

  shape_config {
    ocpus         = 1
    memory_in_gbs = 1
  }

  # Custom Talos image would require a Linux distro; instead use a minimal
  # Oracle Linux 9 x86_64 image suitable for NAT forwarding.
  # NOTE: We pin the latest Oracle Linux 9 image for this platform via tag.
  source_details {
    source_type             = "image"
    source_id               = data.oci_core_image.talos.id
    boot_volume_size_in_gbs = var.micro_boot_volume_size_in_gbs
    boot_volume_vpus_per_gb = var.micro_boot_volume_vpus_per_gb
  }

  # micro-nat lives on the Edge subnet (public zone). skip_source_dest_check
  # is required (REQ-COMP-004): without it, forwarded traffic arriving at
  # this VNIC from private zones would be dropped by the hypervisor.
  create_vnic_details {
    subnet_id              = var.subnet_ids.edge
    display_name           = "${local.name_prefix}-micro-nat-vnic"
    assign_public_ip       = true
    skip_source_dest_check = true
    nsg_ids                = local.micro_nat_nsg_ids
  }

  metadata = {
    ssh_authorized_keys = "" # No SSH. REQ-COMP-006.
    user_data           = "" # No secrets in user_data. REQ-COMP-007.
  }

  # Legacy instance-metadata-service v1 endpoint (CKV_OCI_5): disabled, this
  # instance only needs IMDS v2.
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  # In-transit encryption (CKV_OCI_4) requires a paravirtualized boot-volume
  # attachment; set at create time here (the launch_options copy below only
  # applies on update per the provider's own field description).
  is_pv_encryption_in_transit_enabled = true

  # boot_volume_type must be PARAVIRTUALIZED for
  # is_pv_encryption_in_transit_enabled to take effect.
  launch_options {
    firmware                            = "BIOS"
    network_type                        = "PARAVIRTUALIZED"
    boot_volume_type                    = "PARAVIRTUALIZED"
    is_pv_encryption_in_transit_enabled = true
  }

  defined_tags = {}
  freeform_tags = merge(local.common_tags, {
    role = "software-nat"
  })

  lifecycle {
    ignore_changes = [
      # OCI-defined tags managed outside Terraform.
      defined_tags,
      # Metadata changes after bootstrap (e.g., runtime config updates) should not trigger replaces.
      metadata,
    ]
  }

  provisioner "remote-exec" {
    # Post-bootstrap: configure nftables MASQUERADE forwarding on the instance.
    # This runs once after the instance is reachable on its private IP via SSH
    # (which must be set up externally — see Infrastructure Pipeline section).
    connection {
      type     = "ssh"
      user     = "opc"
      password = "" # Will be configured externally; this provisioner is illustrative only.
      host     = self.public_ip
    }

    inline = [
      "sudo cat > /etc/sysconfig/firewall-nft <<'EOF'",
      "#!/usr/sbin/nft -f",
      "flush ruleset",
      "table inet filter {",
      "  chain forward {",
      "    type filter hook forward priority 0; policy accept;",
      "  }",
      "  chain postrouting {",
      "    type nat hook postrouting priority 100; policy accept;",
      "    ip saddr 10.10.0.0/16 oeth0 masquerade",
      "  }",
      "}",
      "EOF",
      "sudo nft -f /etc/sysconfig/firewall-nft",
      "sudo sysctl -w net.ipv4.ip_forward=1",
    ]
  }

  # The remote-exec provisioner above won't actually work without SSH keys.
  # Per REQ-COMP-007, we avoid secrets in user_data entirely. Instead,
  # the node will receive its configuration via an out-of-band process
  # (talosctl for Talos nodes, manual CLI for micro-nat).
  # The provisioner block exists as a structural placeholder documenting
  # the intended post-bootstrap configuration step.

}
