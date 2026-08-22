# Compute module — locals (node map, shape split, tags)
#
# REQ-COMP-002: ARM budget allocation is expressed as a structured node_map
# variable-like object (hardcoded here per Spec requirements), not scattered
# per-resource. Each node has zone, role, cpu_cores, memory_gbs,
# availability_domain, is_control_plane.
#
# REQ-COMP-001: micro-nat uses free x86 AMD Micro — separate from ARM budget.
#
# Shape constraints verified at plan time via check blocks.

locals {
  platform_name = var.platform_name
  environment   = var.environment

  # Display-name prefix shared across all instances.
  name_prefix = "${var.platform_name}-${var.environment}"

  # Node map: every Talos node defined here. Mirrors REQ-COMP-002's shape
  # split — 1 control plane (2 OCPU / 12 GB) + 2 workers (1 OCPU / 6 GB each).
  # All nodes share the single AD resolved by data.oci_identity_availability_domain.ad_1.
  node_map = {
    cp = {
      role                    = "control-plane"
      zone                    = "management"
      shape                   = "VM.Standard.A1.Flex"
      ocpus                   = 2
      memory_in_gbs           = 12
      boot_volume_vpus_per_gb = var.talos_boot_volume_vpus_per_gb
      boot_volume_size_in_gbs = var.talos_boot_volume_size_in_gbs
      is_control_plane        = true
    }
    worker-0 = {
      role                    = "worker"
      zone                    = "workload"
      shape                   = "VM.Standard.A1.Flex"
      ocpus                   = 1
      memory_in_gbs           = 6
      boot_volume_vpus_per_gb = var.talos_boot_volume_vpus_per_gb
      boot_volume_size_in_gbs = var.talos_boot_volume_size_in_gbs
      is_control_plane        = false
    }
    worker-1 = {
      role                    = "worker"
      zone                    = "workload"
      shape                   = "VM.Standard.A1.Flex"
      ocpus                   = 1
      memory_in_gbs           = 6
      boot_volume_vpus_per_gb = var.talos_boot_volume_vpus_per_gb
      boot_volume_size_in_gbs = var.talos_boot_volume_size_in_gbs
      is_control_plane        = false
    }
  }

  # Validate envelope constraint at plan time.
  total_cpus = sum([for n in local.node_map : n.ocpus])
  total_mem  = sum([for n in local.node_map : n.memory_in_gbs])

  # Subnet ID lookup: keyed by zone string matching node_map.zone values.
  zone_subnet_ids = {
    edge       = var.subnet_ids.edge
    management = var.subnet_ids.management
    workload   = var.subnet_ids.workload
    data       = var.subnet_ids.data
  }

  # NSG attachment map (optional): keyed by zone→purpose if NSGs are present.
  micro_nat_nsg_ids = compact([
    try(var.nsg_ids.ziti, null),
    try(var.nsg_ids.ingress, null),
  ])

  # micro-nat display name.
  micro_nat_display_name = "${local.name_prefix}-micro-nat"

  # Image display name matching data source filter.
  talos_image_display_name = "talos-a1-flex-${var.talos_version}"

  # Platform-managed tags only. OCI-defined tags are handled by
  # lifecycle.ignore_changes to avoid drift on every plan.
  common_tags = {
    "Platform.Name"        = local.platform_name
    "Platform.Environment" = local.environment
  }
}

# ---------------------------------------------------------------------------
# Check blocks — enforce Spec constraints at plan time before API calls.

check "arm_envelope_is_within_always_free_limit" {
  assert {
    condition     = local.total_cpus == var.talos_cpu_cores && local.total_mem == var.talos_memory_gbs
    error_message = "Talos ARM envelope must total ${var.talos_cpu_cores} OCPU / ${var.talos_memory_gbs} GB RAM (Always Free limit). Found ${local.total_cpus} OCPU / ${local.total_mem} GB."
  }
}

check "talos_nodes_are_arm_shapes" {
  assert {
    condition     = alltrue([for n in local.node_map : startswith(n.shape, "VM.Standard.A1")])
    error_message = "All Talos nodes must use A1.Flex ARM64 shapes."
  }
}

check "no_talos_node_in_edge_zone" {
  assert {
    condition     = !contains([for n in local.node_map : n.zone], "edge")
    error_message = "No Talos node may be placed in Edge zone (ADR-0006)."
  }
}
