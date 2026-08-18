# Entry point / file map for this module. Resources are split by concern
# rather than living in this file directly -- see modules/README.md's
# "internal file organization" note. Kept as a real, non-empty file
# (rather than omitted) because validate.yml's module-discovery loop
# looks for a literal main.tf to identify root-module directories to
# validate -- an empty or missing main.tf here would silently exclude
# this module from that automated check.
#
#   compartment.tf    REQ-OCI-001 -- the platform compartment
#   tags.tf           REQ-OCI-004 -- Defined Tags taxonomy (Platform.*, Security.*)
#   iam.tf            REQ-OCI-002/003 -- CI/admin policies, dynamic group
#   state_backend.tf  REQ-OCI-005 -- the OpenTofu remote-state bucket
#   variables.tf / outputs.tf / versions.tf -- standard module contract
