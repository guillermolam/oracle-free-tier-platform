# Validate that the specified zone is available and active
data "upcloud_zones" "available" {}

locals {
  available_zones = data.upcloud_zones.available.zones[*].name
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

# Find the latest Debian 13 image in the specified zone
data "upcloud_storage_devices" "os_images" {
  type = "template"
  zone = var.zone

  depends_on = [terraform_data.zone_validation]
}

locals {
  debian_images = [
    for image in data.upcloud_storage_devices.os_images.storage_devices :
    image if can(regex("Debian 13", image.title))
  ]
  debian_image = length(local.debian_images) > 0 ? local.debian_images[length(local.debian_images) - 1] : null
}

resource "terraform_data" "debian_image_validation" {
  lifecycle {
    precondition {
      condition     = local.debian_image != null
      error_message = "No Debian 13 template image found in zone '${var.zone}'"
    }
  }
}
