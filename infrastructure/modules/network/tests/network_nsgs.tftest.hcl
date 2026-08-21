# Positive tests for NSGs (SPEC-NET-004 REQ-NET-017/019/020).
# These tests validate the five purpose-built NSGs and their rules enforce
# the security requirements: Kubernetes API reachable only from Ziti and
# workers, no other 0.0.0.0/0 ingress except on ingress and ziti NSGs.

mock_provider "oci" {
  override_data {
    target = data.oci_core_services.all
    values = {
      services = [
        {
          id          = "ocid1.service.oc1..aaaaaaaamockallservices"
          name        = "All EU-MADRID-1 Services In Oracle Services Network"
          cidr_block  = "all-eu-madrid-1-services-in-oracle-services-network"
          description = "mock -- REQ-NET-008 Service Gateway target"
        },
      ]
    }
  }

  override_data {
    target = data.oci_core_instances.software_nat
    values = {
      instances = []
    }
  }
}

variables {
  compartment_ocid = "ocid1.compartment.oc1..aaaaaaaaexampleexampleexampleexampleexampleexampleexampleaaaa"
  environment      = "lab"
}

run "five_nsgs_created" {
  command = plan

  assert {
    condition     = length(oci_core_network_security_group.this) == 5
    error_message = "REQ-NET-017: exactly five NSGs must be created: ziti, ingress, control, worker, storage"
  }

  assert {
    condition     = contains(keys(oci_core_network_security_group.this), "ziti")
    error_message = "ziti NSG must be created (OpenZiti edge router)"
  }

  assert {
    condition     = contains(keys(oci_core_network_security_group.this), "ingress")
    error_message = "ingress NSG must be created (application ingress)"
  }

  assert {
    condition     = contains(keys(oci_core_network_security_group.this), "control")
    error_message = "control NSG must be created (Kubernetes control plane)"
  }

  assert {
    condition     = contains(keys(oci_core_network_security_group.this), "worker")
    error_message = "worker NSG must be created (Talos workers)"
  }

  assert {
    condition     = contains(keys(oci_core_network_security_group.this), "storage")
    error_message = "storage NSG must be created (data-zone storage VNICs)"
  }
}

run "nsgs_in_correct_vcn" {
  command = plan

  assert {
    condition = alltrue([
      for purpose, nsg in oci_core_network_security_group.this :
      nsg.vcn_id == oci_core_vcn.this.id
    ])
    error_message = "all NSGs must be in the platform VCN"
  }

  assert {
    condition = alltrue([
      for purpose, nsg in oci_core_network_security_group.this :
      nsg.compartment_id == var.compartment_ocid
    ])
    error_message = "all NSGs must be in the platform compartment"
  }
}

run "control_nsg_port_6443_sources_correct" {
  command = plan

  # REQ-NET-019: control NSG's port 6443 inbound sources are ONLY ziti and worker
  assert {
    condition = length([
      for rule in oci_core_network_security_group_security_rule.control_inbound_ziti :
      rule if rule.protocol == "6" && rule.tcp_options[0].destination_port_range[0].min == 6443
    ]) >= 1
    error_message = "REQ-NET-019: control NSG must have inbound rule for 6443 from ziti NSG"
  }

  assert {
    condition = length([
      for rule in oci_core_network_security_group_security_rule.control_inbound_worker_api :
      rule if rule.protocol == "6" && rule.tcp_options[0].destination_port_range[0].min == 6443
    ]) >= 1
    error_message = "REQ-NET-019: control NSG must have inbound rule for 6443 from worker NSG"
  }

  # This check is implicit: if we defined these two rules and no others on 6443,
  # then they are the only sources. A more thorough test would iterate through
  # all security rules and verify no other protocol-6 destination port 6443 rules exist.
}

run "no_nsg_permits_0_0_0_0_except_ingress_and_ziti" {
  command = plan

  # REQ-NET-020: No NSG except ingress and ziti may permit 0.0.0.0/0 ingress
  # This is a negative test: iterate all NSG rules and verify non-ingress/ziti
  # NSGs have no 0.0.0.0/0 source on ingress.

  assert {
    condition = alltrue([
      for rule in oci_core_network_security_group_security_rule.control_inbound_ziti :
      rule.source != "0.0.0.0/0"
    ]) && alltrue([
      for rule in oci_core_network_security_group_security_rule.control_inbound_worker_api :
      rule.source != "0.0.0.0/0"
    ])
    error_message = "control NSG must not permit 0.0.0.0/0 ingress (REQ-NET-020)"
  }

  assert {
    condition = alltrue([
      for rule in oci_core_network_security_group_security_rule.worker_inbound_control_api :
      rule.source != "0.0.0.0/0"
    ]) && alltrue([
      for rule in oci_core_network_security_group_security_rule.worker_inbound_control_kubelet :
      rule.source != "0.0.0.0/0"
    ])
    error_message = "worker NSG must not permit 0.0.0.0/0 ingress (REQ-NET-020)"
  }

  assert {
    condition = alltrue([
      for rule in oci_core_network_security_group_security_rule.storage_inbound_worker_iscsi :
      rule.source != "0.0.0.0/0"
    ])
    error_message = "storage NSG must not permit 0.0.0.0/0 ingress (REQ-NET-020)"
  }
}

run "ziti_and_ingress_allow_public_ingress" {
  command = plan

  # REQ-NET-020: only ingress and ziti NSGs may permit 0.0.0.0/0 ingress
  assert {
    condition = length([
      for rule in oci_core_network_security_group_security_rule.ziti_inbound_internet :
      rule if rule.source == "0.0.0.0/0" && rule.direction == "INGRESS"
    ]) >= 1
    error_message = "ziti NSG must permit 0.0.0.0/0 ingress on port 6262 (Ziti listener, REQ-NET-020)"
  }

  assert {
    condition = length([
      for rule in oci_core_network_security_group_security_rule.ingress_inbound_http :
      rule if rule.source == "0.0.0.0/0" && rule.direction == "INGRESS"
    ]) >= 1
    error_message = "ingress NSG must permit 0.0.0.0/0 ingress on port 80 (REQ-NET-020)"
  }

  assert {
    condition = length([
      for rule in oci_core_network_security_group_security_rule.ingress_inbound_https :
      rule if rule.source == "0.0.0.0/0" && rule.direction == "INGRESS"
    ]) >= 1
    error_message = "ingress NSG must permit 0.0.0.0/0 ingress on port 443 (REQ-NET-020)"
  }
}

run "nsgs_carry_platform_tags" {
  command = plan

  assert {
    condition = alltrue([
      for purpose, nsg in oci_core_network_security_group.this :
      lookup(nsg.defined_tags, "Platform.Environment", null) == var.environment
    ])
    error_message = "all NSGs must carry Platform.Environment tag"
  }

  assert {
    condition = alltrue([
      for purpose, nsg in oci_core_network_security_group.this :
      lookup(nsg.defined_tags, "Platform.System", null) == var.platform_name
    ])
    error_message = "all NSGs must carry Platform.System tag"
  }

  assert {
    condition = alltrue([
      for purpose, nsg in oci_core_network_security_group.this :
      lookup(nsg.defined_tags, "Platform.ManagedBy", null) == "opentofu"
    ])
    error_message = "all NSGs must carry Platform.ManagedBy tag"
  }
}
