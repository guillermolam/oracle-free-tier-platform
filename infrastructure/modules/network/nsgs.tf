# SPEC-NET-004 (REQ-NET-017/019/020): Five purpose-built Network Security
# Groups for zone-specific enforcement. These NSGs layer on top of the
# baseline Security Lists (security_lists.tf) to implement fine-grained
# allow rules. NSGs are the actual enforcement point; Security Lists are
# the subnet-level backstop (REQ-NET-018).
#
# Per REQ-NET-017 and docs/arch/cloud-deployment.mmd, exactly five NSGs:
# 1. ziti (OpenZiti public edge router): inbound from Internet (6262),
#    inbound from workers (10250 status check), outbound to ziti private
#    router in management zone, outbound to workers.
# 2. ingress (application ingress): inbound from Internet (80/443), outbound
#    to workers.
# 3. control (Kubernetes control plane): inbound from ziti private router
#    (6443 for Kubernetes API via ZTNA), inbound from workers (6443 kubelet),
#    inter-control plane communication.
# 4. worker (Talos worker nodes): inbound from control (6443 kube-apiserver
#    contact), inbound from control (kubelet HTTPS), flannel/cilium ports
#    (4789 VXLAN, 6081 Geneve), outbound to control (6443).
# 5. storage (data-zone storage VNICs): inbound from workers (iSCSI 3260),
#    outbound to workers.

locals {
  # NSG definitions: compartment_id, vcn_id, display_name, description
  # keyed by purpose. Pairs with nsg_rules block below.
  nsg_configs = {
    ziti = {
      display_name = "platform-ziti-nsg"
      description  = "OpenZiti public edge router (SPEC-NET-004 REQ-NET-017). Inbound: Internet to port 6262 (Ziti listener). Inbound: Workers to port 10250 (status check). Outbound: to Ziti private router (mgmt zone) and workers."
    }
    ingress = {
      display_name = "platform-ingress-nsg"
      description  = "Application ingress (SPEC-NET-004 REQ-NET-017). Inbound: Internet to ports 80/443 (HTTP/HTTPS). Outbound: to workers."
    }
    control = {
      display_name = "platform-control-nsg"
      description  = "Kubernetes control plane/API (SPEC-NET-004 REQ-NET-017/019). Inbound: Ziti private router to 6443 (ZTNA admin). Inbound: Workers to 6443 (kubelet). Inter-control plane communication. Outbound: to workers."
    }
    worker = {
      display_name = "platform-worker-nsg"
      description  = "Talos worker nodes (SPEC-NET-004 REQ-NET-017). Inbound: Control plane to 6443/10250 (kubelet), 4789 (VXLAN), 6081 (Geneve). Outbound: to control plane (6443 API), to storage (iSCSI)."
    }
    storage = {
      display_name = "platform-storage-nsg"
      description  = "Data-zone storage VNICs (SPEC-NET-004 REQ-NET-017). Inbound: Workers to 3260 (iSCSI). Outbound: to workers."
    }
  }
}

# Create the five NSGs in the VCN
resource "oci_core_network_security_group" "this" {
  for_each = local.nsg_configs

  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = each.value.display_name
  description    = each.value.description

  freeform_tags = { "provisioned-by" = "opentofu" }
  defined_tags  = local.network_defined_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

# ---- NSG Rules: Ziti Edge Router ----

# Inbound from Internet on port 6262 (Ziti listener)
resource "oci_core_network_security_group_security_rule" "ziti_inbound_internet" {
  network_security_group_id = oci_core_network_security_group.this["ziti"].id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 6262
      max = 6262
    }
  }

  description = "Ziti public listener (SPEC-NET-004 REQ-NET-020: allowed 0.0.0.0/0 ingress)"
}

# Inbound from workers on port 10250 (kubelet status check via Ziti)
resource "oci_core_network_security_group_security_rule" "ziti_inbound_worker_status" {
  network_security_group_id = oci_core_network_security_group.this["ziti"].id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = oci_core_network_security_group.this["worker"].id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 10250
      max = 10250
    }
  }

  description = "Workers status check to Ziti edge router"
}

# Outbound to Ziti private router (management zone, 6443 tunnel handshake)
resource "oci_core_network_security_group_security_rule" "ziti_outbound_control" {
  network_security_group_id = oci_core_network_security_group.this["ziti"].id
  direction                 = "EGRESS"
  protocol                  = "6" # TCP

  destination      = oci_core_network_security_group.this["control"].id
  destination_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }

  description = "Ziti edge router to Ziti private router (management zone)"
}

# Outbound to workers (return traffic, all protocols)
resource "oci_core_network_security_group_security_rule" "ziti_outbound_worker" {
  network_security_group_id = oci_core_network_security_group.this["ziti"].id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = oci_core_network_security_group.this["worker"].id
  destination_type = "NETWORK_SECURITY_GROUP"

  description = "Ziti edge router to workers (return traffic)"
}

# ---- NSG Rules: Ingress (Application) ----

# Inbound from Internet on port 80 (HTTP)
resource "oci_core_network_security_group_security_rule" "ingress_inbound_http" {
  network_security_group_id = oci_core_network_security_group.this["ingress"].id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }

  description = "Application HTTP ingress (SPEC-NET-004 REQ-NET-020: allowed 0.0.0.0/0 ingress)"
}

# Inbound from Internet on port 443 (HTTPS)
resource "oci_core_network_security_group_security_rule" "ingress_inbound_https" {
  network_security_group_id = oci_core_network_security_group.this["ingress"].id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }

  description = "Application HTTPS ingress (SPEC-NET-004 REQ-NET-020: allowed 0.0.0.0/0 ingress)"
}

# Outbound to workers
resource "oci_core_network_security_group_security_rule" "ingress_outbound_worker" {
  network_security_group_id = oci_core_network_security_group.this["ingress"].id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = oci_core_network_security_group.this["worker"].id
  destination_type = "NETWORK_SECURITY_GROUP"

  description = "Ingress to workers (application traffic)"
}

# ---- NSG Rules: Control Plane ----

# Inbound from Ziti private router on 6443 (Kubernetes API via ZTNA)
resource "oci_core_network_security_group_security_rule" "control_inbound_ziti" {
  network_security_group_id = oci_core_network_security_group.this["control"].id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = oci_core_network_security_group.this["ziti"].id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }

  description = "Kubernetes API from Ziti private router (ZTNA admin access, SPEC-NET-004 REQ-NET-019)"
}

# Inbound from workers on 6443 (kubelet API server contact)
resource "oci_core_network_security_group_security_rule" "control_inbound_worker_api" {
  network_security_group_id = oci_core_network_security_group.this["control"].id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = oci_core_network_security_group.this["worker"].id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }

  description = "Kubernetes API from workers (kubelet/kube-proxy cluster join, SPEC-NET-004 REQ-NET-019)"
}

# Inbound from control to control (inter-control plane: etcd, leader election)
resource "oci_core_network_security_group_security_rule" "control_inbound_self" {
  network_security_group_id = oci_core_network_security_group.this["control"].id
  direction                 = "INGRESS"
  protocol                  = "all"

  source      = oci_core_network_security_group.this["control"].id
  source_type = "NETWORK_SECURITY_GROUP"

  description = "Inter-control-plane communication (etcd, leader election, etc.)"
}

# Outbound to workers
resource "oci_core_network_security_group_security_rule" "control_outbound_worker" {
  network_security_group_id = oci_core_network_security_group.this["control"].id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = oci_core_network_security_group.this["worker"].id
  destination_type = "NETWORK_SECURITY_GROUP"

  description = "Control plane to workers"
}

# Outbound to storage (block volume operations)
resource "oci_core_network_security_group_security_rule" "control_outbound_storage" {
  network_security_group_id = oci_core_network_security_group.this["control"].id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = oci_core_network_security_group.this["storage"].id
  destination_type = "NETWORK_SECURITY_GROUP"

  description = "Control plane to storage (block volumes)"
}

# ---- NSG Rules: Worker ----

# Inbound from control plane on 6443 (Kubernetes API server contact)
resource "oci_core_network_security_group_security_rule" "worker_inbound_control_api" {
  network_security_group_id = oci_core_network_security_group.this["worker"].id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = oci_core_network_security_group.this["control"].id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }

  description = "Kubernetes API from control plane (kube-apiserver commands)"
}

# Inbound from control plane on 10250 (kubelet HTTPS API)
resource "oci_core_network_security_group_security_rule" "worker_inbound_control_kubelet" {
  network_security_group_id = oci_core_network_security_group.this["worker"].id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = oci_core_network_security_group.this["control"].id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 10250
      max = 10250
    }
  }

  description = "Kubelet HTTPS API from control plane (logs, exec, metrics)"
}

# Inbound from control plane on 4789 (VXLAN overlay network, Flannel/Cilium)
resource "oci_core_network_security_group_security_rule" "worker_inbound_control_vxlan" {
  network_security_group_id = oci_core_network_security_group.this["worker"].id
  direction                 = "INGRESS"
  protocol                  = "17" # UDP

  source      = oci_core_network_security_group.this["control"].id
  source_type = "NETWORK_SECURITY_GROUP"

  udp_options {
    destination_port_range {
      min = 4789
      max = 4789
    }
  }

  description = "VXLAN overlay network from control plane (Flannel/Cilium)"
}

# Inbound from control plane on 6081 (Geneve overlay network)
resource "oci_core_network_security_group_security_rule" "worker_inbound_control_geneve" {
  network_security_group_id = oci_core_network_security_group.this["worker"].id
  direction                 = "INGRESS"
  protocol                  = "17" # UDP

  source      = oci_core_network_security_group.this["control"].id
  source_type = "NETWORK_SECURITY_GROUP"

  udp_options {
    destination_port_range {
      min = 6081
      max = 6081
    }
  }

  description = "Geneve overlay network from control plane"
}

# Inbound from worker to worker (node-to-node communication)
resource "oci_core_network_security_group_security_rule" "worker_inbound_self" {
  network_security_group_id = oci_core_network_security_group.this["worker"].id
  direction                 = "INGRESS"
  protocol                  = "all"

  source      = oci_core_network_security_group.this["worker"].id
  source_type = "NETWORK_SECURITY_GROUP"

  description = "Worker-to-worker node communication (pod-to-pod via overlay)"
}

# Outbound to control plane (API calls)
resource "oci_core_network_security_group_security_rule" "worker_outbound_control" {
  network_security_group_id = oci_core_network_security_group.this["worker"].id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = oci_core_network_security_group.this["control"].id
  destination_type = "NETWORK_SECURITY_GROUP"

  description = "Workers to control plane"
}

# Outbound to storage (block volume operations)
resource "oci_core_network_security_group_security_rule" "worker_outbound_storage" {
  network_security_group_id = oci_core_network_security_group.this["worker"].id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = oci_core_network_security_group.this["storage"].id
  destination_type = "NETWORK_SECURITY_GROUP"

  description = "Workers to storage (block volumes)"
}

# ---- NSG Rules: Storage ----

# Inbound from workers on 3260 (iSCSI)
resource "oci_core_network_security_group_security_rule" "storage_inbound_worker_iscsi" {
  network_security_group_id = oci_core_network_security_group.this["storage"].id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = oci_core_network_security_group.this["worker"].id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 3260
      max = 3260
    }
  }

  description = "iSCSI from workers (block storage)"
}

# Inbound from control plane on 3260 (iSCSI, for control plane volumes)
resource "oci_core_network_security_group_security_rule" "storage_inbound_control_iscsi" {
  network_security_group_id = oci_core_network_security_group.this["storage"].id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = oci_core_network_security_group.this["control"].id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 3260
      max = 3260
    }
  }

  description = "iSCSI from control plane (block storage)"
}

# Outbound to workers (return traffic)
resource "oci_core_network_security_group_security_rule" "storage_outbound_worker" {
  network_security_group_id = oci_core_network_security_group.this["storage"].id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = oci_core_network_security_group.this["worker"].id
  destination_type = "NETWORK_SECURITY_GROUP"

  description = "Storage to workers (return traffic)"
}

# Outbound to control plane (return traffic)
resource "oci_core_network_security_group_security_rule" "storage_outbound_control" {
  network_security_group_id = oci_core_network_security_group.this["storage"].id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = oci_core_network_security_group.this["control"].id
  destination_type = "NETWORK_SECURITY_GROUP"

  description = "Storage to control plane (return traffic)"
}
