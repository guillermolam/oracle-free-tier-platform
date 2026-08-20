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

  # Default: no software-NAT instance exists yet (the interim no-egress
  # state). Individual runs override this to simulate micro-nat.
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

  variables {
    use_managed_nat             = true
    use_managed_service_gateway = true
  }

  assert {
    condition = alltrue([
      for zone in ["management", "workload", "data"] :
      anytrue([
        for r in oci_core_route_table.this[zone].route_rules :
        r.destination == "0.0.0.0/0" && r.network_entity_id == oci_core_nat_gateway.this[0].id
      ])
    ])
    error_message = "REQ-NET-013: Management, Workload, and Data must route 0.0.0.0/0 to the NAT Gateway"
  }
}

run "all_four_zones_route_services_cidr_to_service_gateway" {
  command = plan

  variables {
    use_managed_nat             = true
    use_managed_service_gateway = true
  }

  assert {
    condition = alltrue([
      for zone, rt in oci_core_route_table.this :
      anytrue([
        for r in rt.route_rules :
        r.destination_type == "SERVICE_CIDR_BLOCK" && r.network_entity_id == oci_core_service_gateway.this[0].id
      ])
    ])
    error_message = "REQ-NET-014: all four route tables must route the OCI Services Network CIDR label to the Service Gateway"
  }
}

run "management_workload_data_route_internet_to_software_nat_target" {
  command = plan

  variables {
    use_managed_nat        = false
    nat_egress_target_ocid = "ocid1.privateip.oc1.eu-madrid-1.aaaaaaaamocksoftwarenat"
  }

  assert {
    condition = alltrue([
      for zone in ["management", "workload", "data"] :
      anytrue([
        for r in oci_core_route_table.this[zone].route_rules :
        r.destination == "0.0.0.0/0" && r.network_entity_id == "ocid1.privateip.oc1.eu-madrid-1.aaaaaaaamocksoftwarenat"
      ])
    ])
    error_message = "REQ-NET-013: with use_managed_nat=false the 0.0.0.0/0 route must target the supplied software-NAT private IP OCID"
  }
}

run "management_workload_data_route_internet_to_discovered_software_nat" {
  command = plan

  variables {
    use_managed_nat = false
  }

  override_data {
    target = data.oci_core_instances.software_nat
    values = {
      instances = [
        {
          agent_config                            = []
          async                                   = false
          availability_config                     = []
          availability_domain                     = "SCLl:EU-MADRID-1-AD-1"
          boot_volume_id                          = null
          capacity_reservation_id                 = null
          cluster_placement_group_id              = null
          compartment_id                          = "ocid1.compartment.oc1..aaaaaaaaexampleexampleexampleexampleexampleexampleexampleaaaa"
          compute_cluster_id                      = null
          create_vnic_details                     = []
          dedicated_vm_host_id                    = null
          defined_tags                            = {}
          display_name                            = "micro-nat"
          extended_metadata                       = {}
          fault_domain                            = null
          hostname_label                          = null
          id                                      = "ocid1.instance.oc1.eu-madrid-1.aaaaaaaamockmicronat"
          image                                   = null
          instance_configuration_id               = null
          instance_options                        = null
          ipxe_script                             = null
          is_ai_enterprise_enabled                = false
          is_cross_numa_node                      = false
          is_pv_encryption_in_transit_enabled     = false
          launch_mode                             = null
          launch_options                          = []
          launch_volume_attachments               = []
          licensing_configs                       = []
          metadata                                = {}
          placement_constraint_details            = []
          platform_config                         = []
          preemptible_instance_config             = []
          preserve_boot_volume                    = false
          preserve_data_volumes_created_at_launch = false
          private_ip                              = "10.10.10.10"
          public_ip                               = null
          region                                  = "eu-madrid-1"
          security_attributes                     = {}
          security_attributes_state               = null
          shape                                   = "VM.Standard.E2.1.Micro"
          shape_config                            = []
          source_details                          = []
          state                                   = "RUNNING"
          subnet_id                               = null
          system_tags                             = {}
          time_created                            = "2026-01-01T00:00:00Z"
          time_maintenance_reboot_due             = null
          update_operation_constraint             = null
          freeform_tags = {
            role             = "software-nat"
            "provisioned-by" = "opentofu"
          }
        },
      ]
    }
  }

  override_data {
    target = data.oci_core_private_ips.software_nat
    values = {
      private_ips = [
        {
          id                          = "ocid1.privateip.oc1.eu-madrid-1.aaaaaaaamockdiscoverednat"
          availability_domain         = "SCLl:EU-MADRID-1-AD-1"
          cidr_prefix_length          = null
          compartment_id              = "ocid1.compartment.oc1..aaaaaaaaexampleexampleexampleexampleexampleexampleexampleaaaa"
          defined_tags                = {}
          display_name                = "micro-nat"
          freeform_tags               = {}
          hostname_label              = null
          ip_address                  = "10.10.10.10"
          ip_state                    = "ASSIGNED"
          ipv4subnet_cidr_at_creation = "10.10.10.0/24"
          is_primary                  = true
          is_reserved                 = false
          lifetime                    = "EPHEMERAL"
          route_table_id              = null
          subnet_id                   = "ocid1.subnet.oc1.eu-madrid-1.aaaaaaaamockedgesubnet"
          time_created                = "2026-01-01T00:00:00Z"
          vlan_id                     = null
          vnic_id                     = null
        },
      ]
    }
  }

  assert {
    condition = alltrue([
      for zone in ["management", "workload", "data"] :
      anytrue([
        for r in oci_core_route_table.this[zone].route_rules :
        r.destination == "0.0.0.0/0" && r.network_entity_id == "ocid1.privateip.oc1.eu-madrid-1.aaaaaaaamockdiscoverednat"
      ])
    ])
    error_message = "REQ-NET-013: with use_managed_nat=false and no explicit target, the 0.0.0.0/0 route must resolve to the instance discovered by tag role=software-nat (no cross-unit Terragrunt dependency)"
  }
}

run "interim_no_egress_state_has_no_internet_route_outside_edge" {
  command = plan

  assert {
    condition = alltrue([
      for zone in ["management", "workload", "data"] :
      !anytrue([
        for r in oci_core_route_table.this[zone].route_rules :
        r.destination == "0.0.0.0/0"
      ])
    ])
    error_message = "before micro-nat exists (nat_egress_target_ocid unset) and with the managed NAT disabled, Management/Workload/Data must have NO 0.0.0.0/0 route at all -- the interim no-egress state, not an invalid reference"
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
