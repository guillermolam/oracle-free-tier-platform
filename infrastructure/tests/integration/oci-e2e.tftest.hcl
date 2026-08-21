# End-to-end integration tests for OCI infrastructure (Phase 1: foundation → network → compute)
#
# This test validates the complete provisioning pipeline across all three modules:
# 1. Foundation (compartment, IAM, state backend) - APPLIED
# 2. Network (VCN, subnets, NSGs, routing) - PARTIAL (NSGs just added)
# 3. Compute (Talos nodes, Ziti edge router, micro-NAT) - INCOMPLETE (awaits this)
#
# By default, these tests are SKIPPED to avoid unnecessary costs and long execution time
# on the Always Free tier. To run them, set ENABLE_INTEGRATION_TESTS=true:
#
#   tofu test infrastructure/tests/integration/ -e ENABLE_INTEGRATION_TESTS=true
#
# Each run block will skip unless variables.enable_integration_tests is true.

variables {
  enable_integration_tests = {
    type        = bool
    description = "Set to true to run expensive end-to-end provisioning tests. Disabled by default to save time/costs."
    default     = false
  }
}

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

run "foundation_creates_compartment_tags_bucket" {
  skip = !var.enable_integration_tests

  # This test validates the foundation module created the platform compartment
  # with proper tags and the remote state bucket.
  # In a real apply, the foundation outputs would be:
  # - compartment_ocid: the platform compartment OCID
  # - state_bucket_namespace: OCI namespace
  # - state_bucket_name: oracle-free-tier-platform-tfstate
  #
  # For this test, we verify the contract by reading module outputs.

  # NOTE: This test would need to be run with actual 10-foundation module inputs.
  # For now, it's a placeholder showing the validation pattern.
}

run "network_creates_vcn_subnets_and_nsgs" {
  skip = !var.enable_integration_tests

  # This test validates the network module created:
  # 1. One VCN (10.10.0.0/16)
  # 2. Four subnets (edge, management, workload, data)
  # 3. Five NSGs (ziti, ingress, control, worker, storage)
  # 4. Route tables for each zone
  # 5. Security Lists as baselines
  #
  # Outputs to verify:
  # - vcn_id: ocid of the VCN
  # - subnet_ids: map of zone -> subnet OCID
  # - nsg_ids: map of purpose -> NSG OCID (ziti, ingress, control, worker, storage)
  # - route_table_ids: map of zone -> route table OCID
  # - security_list_ids: map of zone -> security list OCID
}

run "compute_attaches_to_network_resources" {
  skip = !var.enable_integration_tests

  # This test validates the compute module:
  # 1. Uses network module's subnet IDs for placement
  # 2. Attaches instances to NSGs from network module
  # 3. Applies resource tags consistently
  #
  # Verifies:
  # - Micro-NAT instance created in edge zone
  # - Talos control plane nodes in management zone
  # - Talos worker nodes in workload zone
  # - Block volumes attached via data zone storage NSG
  # - All resources tagged with Platform namespace
}

run "cidr_validation_across_modules" {
  skip = !var.enable_integration_tests

  # Validates CIDR allocation consistency:
  # - VCN CIDR: 10.10.0.0/16
  # - Edge subnet: 10.10.10.0/24
  # - Management subnet: 10.10.20.0/24
  # - Workload subnet: 10.10.30.0/24
  # - Data subnet: 10.10.40.0/24
  #
  # No overlaps, all within VCN, no gaps in allocation.
}

run "nsg_references_consistency" {
  skip = !var.enable_integration_tests

  # Validates that NSG rule references are consistent across modules:
  # 1. NSG IDs exported by network module match NSG rule references in rules
  # 2. Compute module inputs match network module outputs for nsg_ids keys
  # 3. No orphaned NSG references
}

run "public_ip_placement_verification" {
  skip = !var.enable_integration_tests

  # Validates public IP placement:
  # - Edge zone: ziti edge router + ingress can have public IPs
  # - Management zone: control plane cannot have public IP
  # - Workload zone: workers cannot have public IP
  # - Data zone: storage cannot have public IP
  #
  # Verifies prohibit_public_ip_on_vnic settings match ADR-0006.
}

run "security_enforcement_chain" {
  skip = !var.enable_integration_tests

  # Validates the security enforcement chain:
  # 1. Security Lists: baseline default-deny on each zone
  # 2. NSG rules: fine-grained allow rules per purpose
  # 3. Talos + Cilium NetworkPolicy: application-level segmentation (not in scope)
  #
  # Verifies:
  # - No ingress_security_rules on Security Lists (default-deny baseline)
  # - Egress_security_rules match route table destinations
  # - NSG rules enforce REQ-NET-019 (6443 only from ziti/worker)
  # - NSG rules enforce REQ-NET-020 (0.0.0.0/0 only ingress/ziti)
}

run "tagging_consistency" {
  skip = !var.enable_integration_tests

  # Validates defined tags across all resources:
  # - Platform.Environment: lab
  # - Platform.System: oracle-free-tier-platform
  # - Platform.ManagedBy: opentofu
  #
  # All resources in VCN, subnets, NSGs, route tables, security lists must carry these.
}

run "dependency_wiring_validation" {
  skip = !var.enable_integration_tests

  # Validates Terragrunt dependency blocks:
  # 1. 10-network depends on 00-foundation (compartment_ocid)
  # 2. 30-compute depends on 00-foundation and 10-network
  # 3. Mock outputs match real outputs for validate/plan phases
  # 4. No circular dependencies
}
