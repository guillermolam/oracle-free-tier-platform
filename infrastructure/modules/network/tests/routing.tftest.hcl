# Positive tests for SPEC-NET-003 (REQ-NET-011..015). REQ-NET-013 ("no
# route table other than Edge references the Internet Gateway") is the
# binding security control -- tested here by positively asserting its
# absence on Management/Workload/Data, not merely asserting the NAT route
# is present (a table could have both and still pass a presence-only
# check).

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

run "four_route_tables_one_per_zone" {
  command = plan

  assert {
    condition     = length(oci_core_route_table.this) == 4
    error_message = "REQ-NET-011: exactly four route tables must exist, one per trust zone"
  }
}

run "every_subnet_uses_its_own_zone_route_table_not_the_default" {
  command = plan

  assert {
    condition = alltrue([
      for zone, subnet in oci_core_subnet.this :
      subnet.route_table_id == oci_core_route_table.this[zone].id
    ])
    error_message = "REQ-NET-011: every subnet must use its own zone's explicit route table, never the VCN default"
  }
}

run "edge_route_table_routes_internet_to_igw" {
  command = plan

  assert {
    condition = anytrue([
      for r in oci_core_route_table.this["edge"].route_rules :
      r.destination == "0.0.0.0/0" && r.network_entity_id == oci_core_internet_gateway.this.id
    ])
    error_message = "REQ-NET-012: the Edge route table must route 0.0.0.0/0 to the Internet Gateway"
  }
}

run "management_workload_data_never_reference_the_internet_gateway" {
  command = plan

  assert {
    condition = alltrue([
      for zone in ["management", "workload", "data"] :
      !anytrue([
        for r in oci_core_route_table.this[zone].route_rules :
        r.network_entity_id == oci_core_internet_gateway.this.id
      ])
    ])
    error_message = "REQ-NET-013: no route table other than Edge may ever reference the Internet Gateway -- this is the binding security control, not just 'NAT route is present'"
  }
}

run "management_workload_data_route_internet_to_nat_only" {
  command = plan

  assert {
    condition = alltrue([
      for zone in ["management", "workload", "data"] :
      anytrue([
        for r in oci_core_route_table.this[zone].route_rules :
        r.destination == "0.0.0.0/0" && r.network_entity_id == oci_core_nat_gateway.this.id
      ])
    ])
    error_message = "REQ-NET-013: Management, Workload, and Data must route 0.0.0.0/0 to the NAT Gateway"
  }
}

run "all_four_zones_route_services_cidr_to_service_gateway" {
  command = plan

  assert {
    condition = alltrue([
      for zone, rt in oci_core_route_table.this :
      anytrue([
        for r in rt.route_rules :
        r.destination_type == "SERVICE_CIDR_BLOCK" && r.network_entity_id == oci_core_service_gateway.this.id
      ])
    ])
    error_message = "REQ-NET-014: all four route tables must route the OCI Services Network CIDR label to the Service Gateway"
  }
}

run "no_route_table_references_the_drg" {
  command = plan

  assert {
    condition = alltrue([
      for zone, rt in oci_core_route_table.this :
      !anytrue([
        for r in rt.route_rules :
        r.network_entity_id == oci_core_drg.this.id
      ])
    ])
    error_message = "REQ-NET-015/ADR-0008: the Management route table's DRG slot must stay unpopulated in M1 -- no route table may reference the DRG until I21"
  }
}

run "route_tables_carry_no_oracle_managed_tag_keys" {
  command = plan

  assert {
    condition = alltrue([
      for zone, rt in oci_core_route_table.this :
      !anytrue([for k in keys(rt.defined_tags) : strcontains(k, "Oracle-Tags")])
    ])
    error_message = "this module must never itself declare an Oracle-Tags.* key on any route table"
  }
}
