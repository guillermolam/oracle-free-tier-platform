# Entry point / file map for this module. Resources are split by concern
# rather than living in this file directly -- see modules/README.md's
# "internal file organization" note. Kept as a real, non-empty file
# (rather than omitted) because validate.yml's module-discovery loop
# looks for a literal main.tf to identify root-module directories to
# validate -- an empty or missing main.tf here would silently exclude
# this module from that automated check.
#
#   vcn.tf       REQ-NET-001 -- the platform VCN; also the CIDR/tag locals
#                and the check block self-validating them
#   subnets.tf   REQ-NET-002/003/004 -- the four trust-zone subnets
#   variables.tf / outputs.tf / versions.tf -- standard module contract
