# SPEC-NET-004 (REQ-NET-016/018 only -- the coarse Security List baseline).
# Pulled forward from PR C3's original scope: applying IGW/NAT routing
# (gateways.tf/routing.tf) while every subnet still inherited OCI's
# permissive default Security List (TCP/22 + ICMP from 0.0.0.0/0) would
# have left a real, avoidable transitional exposure -- not a hypothetical
# one, since Edge specifically becomes IGW-routable in this same PR. This
# file closes that gap with the minimum necessary baseline; it does NOT
# implement REQ-NET-017/019/020 (the five purpose-built NSGs, the
# `control` NSG's port-6443 restriction, OpenZiti-specific rules,
# Kubernetes control-plane authorization) -- those remain PR C3, per
# REQ-NET-018's own division of labor: "NSGs are the actual enforcement
# point, Security Lists are the subnet-level backstop."
#
# Ingress: empty on all four zones, deliberately. REQ-NET-018 mandates
# default-deny "except what is explicitly required for the subnet to
# function at the OCI platform level (e.g., VCN-internal DNS)" -- OCI's
# VCN Resolver and instance metadata service operate outside normal
# Security List enforcement (the same class of platform-level exemption
# AWS's 169.254.169.254 metadata endpoint has), so no explicit DNS rule
# is required for the subnet itself to function. An empty ingress set is
# valid and sufficient today; nothing currently needs inbound access.
#
# Egress: not a blanket "all protocols to 0.0.0.0/0" copy of OCI's
# default -- scoped to exactly the two destinations routing.tf's route
# tables already send traffic to (0.0.0.0/0 via NAT/IGW, the Services
# CIDR via the Service Gateway). A route without a matching egress rule
# would be dead on arrival, so this is the necessary complement to
# already-approved PR C2 routing, not new speculative capability.
# Protocol-level restriction is deliberately NOT attempted here: which
# specific protocols future workloads need is unknowable before I04
# compute exists, and guessing narrower would be speculative in the
# other direction.
resource "oci_core_security_list" "this" {
  for_each = local.subnet_cidrs

  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "platform-${each.key}-sl"

  # No ingress_security_rules block: zero rules, default-deny.

  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    description      = "Matches this zone's NAT/IGW route (REQ-NET-013/012) -- a route without this would be unusable"
  }

  egress_security_rules {
    destination      = local.all_services_in_oracle_services_network.cidr_block
    destination_type = "SERVICE_CIDR_BLOCK"
    protocol         = "all"
    description      = "Matches this zone's Service Gateway route (REQ-NET-014)"
  }

  freeform_tags = { "provisioned-by" = "opentofu" }
  defined_tags  = local.network_defined_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}
