# Positive tests for SPEC-NET-002 (REQ-NET-006..010): the four gateway
# objects and the DRG's inert configuration.

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
  compartment_ocid             = "ocid1.compartment.oc1..aaaaaaaaexampleexampleexampleexampleexampleexampleexampleaaaa"
  environment                  = "lab"
  use_managed_nat              = true
  use_managed_service_gateway  = true
  manage_inert_drg_route_table = true # exercises the still-authoritative ADR-0008 Option B path -- see the dedicated "disabled by default" run below for the current real-deployment default
}

run "internet_gateway_enabled" {
  command = plan

  assert {
    condition     = oci_core_internet_gateway.this.enabled == true
    error_message = "REQ-NET-006: the Internet Gateway must exist and be enabled"
  }
}

run "nat_gateway_exists" {
  command = plan

  assert {
    condition     = oci_core_nat_gateway.this[0].vcn_id == oci_core_vcn.this.id
    error_message = "REQ-NET-007: the NAT Gateway must be attached to the platform VCN"
  }
}

run "service_gateway_targets_all_services" {
  command = plan

  assert {
    condition     = tolist(oci_core_service_gateway.this[0].services)[0].service_id == "ocid1.service.oc1..aaaaaaaamockallservices"
    error_message = "REQ-NET-008: the Service Gateway must target the OCI Services Network CIDR label, resolved via data.oci_core_services, not hardcoded"
  }
}

run "drg_exists_and_is_attached" {
  command = plan

  assert {
    condition     = oci_core_drg_attachment.vcn[0].drg_id == oci_core_drg.this.id
    error_message = "REQ-NET-009: the DRG must be attached to the VCN"
  }

  assert {
    condition     = tolist(oci_core_drg_attachment.vcn[0].network_details)[0].type == "VCN"
    error_message = "REQ-NET-009: the DRG attachment must attach the VCN specifically"
  }
}

run "drg_route_table_is_inert" {
  command = plan

  assert {
    condition     = oci_core_drg_attachment.vcn[0].drg_route_table_id == oci_core_drg_route_table.inert[0].id
    error_message = "REQ-NET-009/ADR-0008: the DRG attachment must reference this module's own empty DRG route table, not the account default"
  }

  # What this run does NOT and cannot test: that
  # import_drg_route_distribution_id stays null (REQ-NET-009's "no
  # propagation" requirement). mock_provider synthesizes a plausible fake
  # value for every computed attribute regardless of whether this
  # module's config leaves it unset -- confirmed empirically (the mock
  # always returns a non-null synthetic ID here, identical in kind to the
  # defined_tags/ignore_changes constraint documented in
  # infrastructure/modules/foundation/tests/state_bucket_tag_ownership.tftest.hcl).
  # The only source of truth for "genuinely unset" vs. "computed" is the
  # real provider. Verified instead by (a) this module's own gateways.tf
  # never declaring an oci_core_drg_route_distribution resource at all --
  # grep-verifiable, not runtime-verifiable -- and (b) the real
  # post-apply plan/OCI CLI check in the PR C2 deployment report.
}

run "inert_drg_route_table_disabled_by_default" {
  command = plan

  variables {
    manage_inert_drg_route_table = false # this run's own override -- the current real-deployment default
  }

  assert {
    condition     = length(oci_core_drg_route_table.inert) == 0
    error_message = "manage_inert_drg_route_table defaults to false (real OCI service-limit constraint, see gateways.tf) -- the custom inert table must not be planned"
  }

  assert {
    condition     = length(oci_core_drg_attachment.vcn) == 0
    error_message = "with the inert table disabled, the DRG attachment (which requires it) must also not be planned -- REQ-NET-009's attachment stays genuinely absent, not attached-to-nothing"
  }

  assert {
    condition     = oci_core_drg.this.display_name == "platform-drg"
    error_message = "the DRG object itself is unconditional -- only its attachment/inert-table are gated"
  }
}

run "gateways_carry_no_oracle_managed_tag_keys" {
  command = plan

  assert {
    condition = alltrue([
      !anytrue([for k in keys(oci_core_internet_gateway.this.defined_tags) : strcontains(k, "Oracle-Tags")]),
      !anytrue([for k in keys(oci_core_nat_gateway.this[0].defined_tags) : strcontains(k, "Oracle-Tags")]),
      !anytrue([for k in keys(oci_core_service_gateway.this[0].defined_tags) : strcontains(k, "Oracle-Tags")]),
      !anytrue([for k in keys(oci_core_drg.this.defined_tags) : strcontains(k, "Oracle-Tags")]),
    ])
    error_message = "this module must never itself declare an Oracle-Tags.* key on any gateway resource"
  }
}
