# Validate that the specified zone is available and active
data "upcloud_zones" "available" {}

locals {
  # UpCloud provider 5.x exposes zone identifiers through `zone_ids`.
  # Keep validation tied to the provider schema rather than a stale `zones`
  # object shape from older releases.
  available_zones = toset(data.upcloud_zones.available.zone_ids)
  zone_valid      = contains(local.available_zones, var.zone)
}

resource "terraform_data" "zone_validation" {
  lifecycle {
    precondition {
      condition     = local.zone_valid
      error_message = "Zone '${var.zone}' is not available. Available zones: ${join(", ", local.available_zones)}"
    }
  }
}

# Find the most recent Debian 13 template. The provider's current data source
# returns one selected storage object; older `upcloud_storage_devices` list
# lookups are no longer part of the v5 schema.
data "upcloud_storage" "os_image" {
  type        = "template"
  name_regex  = "^Debian 13.*"
  most_recent = true

  depends_on = [terraform_data.zone_validation]
}

resource "terraform_data" "debian_image_validation" {
  lifecycle {
    precondition {
      condition     = data.upcloud_storage.os_image.id != null
      error_message = "No Debian 13 template image found in zone '${var.zone}'"
    }
  }
}
