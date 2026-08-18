# Negative tests -- every one of these MUST fail. See README.md's "Tests"
# section for why this module has only one variable-driven negative case:
# CIDRs are hardcoded locals (REQ-NET-001/002), not variables, so there is
# no user-input surface for malformed/overlapping/out-of-range CIDR
# negative tests the way infrastructure/modules/foundation has for its
# string/OCID variables. That protection is enforced instead by vcn.tf's
# `check` block (validated positively in network.tftest.hcl -- a broken
# check block fails `tofu test` outright, since `tofu validate`/`plan`
# would fail first).

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

run "invalid_environment_rejected" {
  command = plan

  variables {
    environment = "production" # not one of lab|staging|prod
  }

  expect_failures = [var.environment]
}

run "invalid_compartment_ocid_rejected" {
  command = plan

  variables {
    compartment_ocid = "not-an-ocid"
  }

  expect_failures = [var.compartment_ocid]
}
