# Positive tests for the REQ-NET-016/018 baseline Security List pull-
# forward. These are the critical invariants: the whole point of this
# file's existence is proving IGW routing (gateways.tf/routing.tf, same
# PR) never combines with an inherited permissive default to create real
# exposure. NSG-level tests (REQ-NET-017/019/020) are PR C3's own test
# file, not this one.

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

run "four_security_lists_one_per_zone" {
  command = plan

  assert {
    condition     = length(oci_core_security_list.this) == 4
    error_message = "REQ-NET-016: exactly four Security Lists must exist, one per trust zone"
  }
}

run "no_zone_permits_ssh_from_the_internet" {
  command = plan

  assert {
    condition = alltrue([
      for zone, sl in oci_core_security_list.this :
      !anytrue([
        for r in sl.ingress_security_rules :
        r.source == "0.0.0.0/0" && (
          r.protocol == "6" &&
          try(r.tcp_options[0].destination_port_range[0].min, null) == 22
        )
      ])
    ])
    error_message = "no zone (Edge, Management, Workload, or Data) may permit TCP/22 from 0.0.0.0/0"
  }
}

run "edge_has_no_unauthorized_ingress" {
  command = plan

  assert {
    condition     = length(oci_core_security_list.this["edge"].ingress_security_rules) == 0
    error_message = "REQ-NET-018: Edge is IGW-routable in this same PR (gateways.tf/routing.tf) -- routable must not imply authorized; ingress stays empty until PR C3's NSGs add precise rules"
  }
}

run "management_has_no_internet_ingress" {
  command = plan

  assert {
    condition     = length(oci_core_security_list.this["management"].ingress_security_rules) == 0
    error_message = "Management must have zero ingress rules (default-deny baseline, REQ-NET-018)"
  }
}

run "workload_has_no_internet_ingress" {
  command = plan

  assert {
    condition     = length(oci_core_security_list.this["workload"].ingress_security_rules) == 0
    error_message = "Workload must have zero ingress rules (default-deny baseline, REQ-NET-018)"
  }
}

run "data_has_no_internet_ingress" {
  command = plan

  assert {
    condition     = length(oci_core_security_list.this["data"].ingress_security_rules) == 0
    error_message = "Data must have zero ingress rules (default-deny baseline, REQ-NET-018)"
  }
}

run "no_zone_permits_unrestricted_ingress_of_any_kind" {
  command = plan

  assert {
    condition = alltrue([
      for zone, sl in oci_core_security_list.this : length(sl.ingress_security_rules) == 0
    ])
    error_message = "every zone's Security List must have zero ingress rules today -- the strongest possible form of 'no unrestricted ingress exists anywhere'"
  }
}

run "egress_scoped_to_exactly_what_routing_needs" {
  command = plan

  assert {
    condition = alltrue([
      for zone, sl in oci_core_security_list.this : length(sl.egress_security_rules) == 2
    ])
    error_message = "egress must be scoped to exactly the two destinations routing.tf's route tables send traffic to (0.0.0.0/0, Services CIDR) -- not a blanket reproduction of OCI's default"
  }

  assert {
    condition = alltrue([
      for zone, sl in oci_core_security_list.this :
      anytrue([for r in sl.egress_security_rules : r.destination == "0.0.0.0/0" && r.destination_type == "CIDR_BLOCK"])
    ])
    error_message = "every zone must allow egress to 0.0.0.0/0 -- otherwise its NAT/IGW route (REQ-NET-012/013) would be unusable"
  }

  assert {
    condition = alltrue([
      for zone, sl in oci_core_security_list.this :
      anytrue([for r in sl.egress_security_rules : r.destination_type == "SERVICE_CIDR_BLOCK"])
    ])
    error_message = "every zone must allow egress to the Services CIDR label -- otherwise its Service Gateway route (REQ-NET-014) would be unusable"
  }
}

run "every_subnet_uses_its_own_zone_security_list_not_the_default" {
  command = plan

  assert {
    condition = alltrue([
      for zone, subnet in oci_core_subnet.this :
      length(subnet.security_list_ids) == 1 && contains(subnet.security_list_ids, oci_core_security_list.this[zone].id)
    ])
    error_message = "every subnet must reference its own zone's Security List -- the OCI default Security List must become INTENTIONALLY UNUSED, not silently inherited"
  }
}

run "security_lists_carry_no_oracle_managed_tag_keys" {
  command = plan

  assert {
    condition = alltrue([
      for zone, sl in oci_core_security_list.this :
      !anytrue([for k in keys(sl.defined_tags) : strcontains(k, "Oracle-Tags")])
    ])
    error_message = "this module must never itself declare an Oracle-Tags.* key on any Security List"
  }
}
