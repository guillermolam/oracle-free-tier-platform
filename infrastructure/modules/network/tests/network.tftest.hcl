# Positive tests -- module contract at plan time, no real OCI credentials
# required (mock_provider stands in for the real provider).

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
}

variables {
  compartment_ocid = "ocid1.compartment.oc1..aaaaaaaaexampleexampleexampleexampleexampleexampleexampleaaaa"
  environment      = "lab"
}

run "vcn_has_exact_cidr" {
  command = plan

  assert {
    condition     = oci_core_vcn.this.cidr_blocks[0] == "10.10.0.0/16"
    error_message = "REQ-NET-001: VCN must use exactly 10.10.0.0/16"
  }

  assert {
    condition     = length(oci_core_vcn.this.cidr_blocks) == 1
    error_message = "REQ-NET-001: exactly one VCN CIDR block, not multiple"
  }
}

run "four_subnets_with_exact_cidrs" {
  command = plan

  assert {
    condition     = length(oci_core_subnet.this) == 4
    error_message = "REQ-NET-002: exactly four trust-zone subnets must exist"
  }

  assert {
    condition     = oci_core_subnet.this["edge"].cidr_block == "10.10.10.0/24"
    error_message = "REQ-NET-002: Edge subnet must use exactly 10.10.10.0/24"
  }

  assert {
    condition     = oci_core_subnet.this["management"].cidr_block == "10.10.20.0/24"
    error_message = "REQ-NET-002: Management subnet must use exactly 10.10.20.0/24"
  }

  assert {
    condition     = oci_core_subnet.this["workload"].cidr_block == "10.10.30.0/24"
    error_message = "REQ-NET-002: Workload subnet must use exactly 10.10.30.0/24"
  }

  assert {
    condition     = oci_core_subnet.this["data"].cidr_block == "10.10.40.0/24"
    error_message = "REQ-NET-002: Data subnet must use exactly 10.10.40.0/24"
  }
}

run "edge_subnet_allows_public_ip" {
  command = plan

  assert {
    condition     = oci_core_subnet.this["edge"].prohibit_public_ip_on_vnic == false
    error_message = "REQ-NET-004: Edge subnet MAY allow public IP -- prohibit_public_ip_on_vnic must be false"
  }
}

run "management_subnet_prohibits_public_ip" {
  command = plan

  assert {
    condition     = oci_core_subnet.this["management"].prohibit_public_ip_on_vnic == true
    error_message = "REQ-NET-003: Management subnet must prohibit public IP"
  }
}

run "workload_subnet_prohibits_public_ip" {
  command = plan

  assert {
    condition     = oci_core_subnet.this["workload"].prohibit_public_ip_on_vnic == true
    error_message = "REQ-NET-003: Workload subnet must prohibit public IP"
  }
}

run "data_subnet_prohibits_public_ip" {
  command = plan

  assert {
    condition     = oci_core_subnet.this["data"].prohibit_public_ip_on_vnic == true
    error_message = "REQ-NET-003: Data subnet must prohibit public IP"
  }
}

run "subnets_carry_no_oracle_managed_tag_keys" {
  command = plan

  assert {
    condition = alltrue([
      for zone, subnet in oci_core_subnet.this :
      !anytrue([for k in keys(subnet.defined_tags) : strcontains(k, "Oracle-Tags")])
    ])
    error_message = "this module must never itself declare an Oracle-Tags.* key -- see subnets.tf/vcn.tf's ignore_changes"
  }
}

run "vcn_and_subnets_use_the_platform_compartment" {
  command = plan

  assert {
    condition     = oci_core_vcn.this.compartment_id == var.compartment_ocid
    error_message = "the VCN must live in the platform compartment passed in, never a hardcoded compartment"
  }

  assert {
    condition = alltrue([
      for zone, subnet in oci_core_subnet.this : subnet.compartment_id == var.compartment_ocid
    ])
    error_message = "every subnet must live in the platform compartment passed in"
  }
}
