# Compute module — output contract (SPEC-COMP-001)
#
# These outputs are consumed by downstream state units and the live Terragrunt
# layer. All values are derived from the resources created above; none are
# hardcoded OCIDs.

output "micro_nat_private_ip_ocid" {
  description = "Private IP OCID of the micro-nat instance, resolved via data.oci_core_private_ips. Used by 10-network for egress route targeting."
  value       = data.oci_core_private_ips.micro_nat.private_ips[0].id
}

output "node_ocids_by_role" {
  description = "Map of Talos node OCIDs keyed by role (control-plane, worker)."
  value = {
    control-plane = oci_core_instance.talos_node["cp"].id
    worker        = oci_core_instance.talos_node["worker-0"].id
  }
}

output "node_private_ips_by_role" {
  description = "Map of Talos node private IPs keyed by role."
  value = {
    control-plane = oci_core_instance.talos_node["cp"].private_ip
    worker        = oci_core_instance.talos_node["worker-0"].private_ip
  }
}

output "talos_endpoints" {
  description = "Map of Talos node private IPs keyed by role, formatted for talosctl."
  value = {
    control-plane = "https://${oci_core_instance.talos_node["cp"].private_ip}:54322"
    worker        = "https://${oci_core_instance.talos_node["worker-0"].private_ip}:54322"
  }
}

output "talos_image_ocid" {
  description = "OCID of the pinned Talos custom image imported into this tenancy."
  value       = data.oci_core_image.talos.id
}
