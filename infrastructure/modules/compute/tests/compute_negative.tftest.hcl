# Compute module — negative tests (SPEC-COMP-001)
#
# Mock provider and variable definitions for tofu test.
# These inputs are expected to cause plan/apply failures.

mock_provider "oci" {
  override_data {
    target = data.oci_core_private_ips.micro_nat
    values = {
      private_ips = []
    }
  }

  # check "talos_image_found" in data.tf asserts images is non-empty; the
  # mock provider otherwise defaults list attributes to empty.
  override_data {
    target = data.oci_core_images.talos
    values = {
      images = [
        {
          id = "ocid1.image.oc1..aaaaaaaatalostestimageaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        }
      ]
    }
  }

  override_data {
    target = oci_core_instance.micro_nat
    values = {
      skip_source_dest_check = false
      assign_public_ip       = false
    }
  }

  override_data {
    target = oci_core_instance.talos_node
    values = {
      assign_public_ip = true
    }
  }
}

variables {
  compartment_ocid = "ocid1.compartment.oc1..aaaaaaaaexampleexampleexampleexampleexampleexampleexampleaaaa"
  environment      = "lab"
  platform_name    = "oracle-free-tier-platform"
  subnet_ids = {
    edge       = "ocid1.subnet.oc1..edgexample"
    management = "ocid1.subnet.oc1..managementexample"
    workload   = "ocid1.subnet.oc1..workloadexample"
    data       = "ocid1.subnet.oc1..dataexample"
  }
}
