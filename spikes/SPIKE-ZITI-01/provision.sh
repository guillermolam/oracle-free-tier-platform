#!/usr/bin/env bash
# SPIKE-EGRESS-01 lab provisioning (throwaway). Run from repo root.
set -euo pipefail
export OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True 2>/dev/null || true

C=ocid1.compartment.oc1..aaaaaaaa5ha6ylst36ct7ax2rsmlkezhvu6g6is5k4jknmr3mtkfnntadeyq
T=ocid1.tenancy.oc1..aaaaaaaao6xpusejjs2bqb5lyeccjkjwvy5jvstzabpgzm6fhzbznu7td3fq
AD="SCLl:EU-MADRID-1-AD-1"
MY_IP="81.35.27.240/32"
KEY="$(cat spikes/SPIKE-EGRESS-01/spike_ed25519.pub)"

EDGE_SUBNET=ocid1.subnet.oc1.eu-madrid-1.aaaaaaaatjvj32htvalqyfxn6hmoq5it4gdgitztvwppa7c45lt2r73qwkha
WL_SUBNET=ocid1.subnet.oc1.eu-madrid-1.aaaaaaaao3pzghxzqjgoxtwjpsjilmutiwylsmbkmnggbp326ldy7omhlova

echo "== VCN of edge subnet =="
VCN_ID=$(oci network subnet get --subnet-id "$EDGE_SUBNET" --query 'data."vcn-id"' --raw-output 2>/dev/null)
echo "VCN_ID=$VCN_ID"

echo "== Workload subnet route table (egress-under-test evidence) =="
WL_RT=$(oci network subnet get --subnet-id "$WL_SUBNET" --query 'data."route-table-id"' --raw-output)
oci network route-table get --rt-id "$WL_RT" --query 'data."route-rules"[].{target:targetType, dest:"destination"}' 2>/dev/null || echo "no route rules"

echo "== create/find spike-gw-nsg =="
GW_NSG=$(oci network nsg list -c "$C" --all --query "data[?\"display-name\"=='spike-gw-nsg'].id | [0]" --raw-output 2>/dev/null || true)
if [ -z "$GW_NSG" ] || [ "$GW_NSG" = "null" ]; then
  GW_NSG=$(oci network nsg create -c "$C" --vcn-id "$VCN_ID" --display-name spike-gw-nsg --query 'data.id' --raw-output)
  echo "GW_NSG=new:$GW_NSG"
  oci network nsg rules add --nsg-id "$GW_NSG" --security-rules '[
    {"description":"ssh admin","direction":"INGRESS","protocol":"6","source":"'$MY_IP'","sourceType":"CIDR_BLOCK","tcpOptions":{"destinationPortRange":{"min":22,"max":22}}},
    {"description":"workerd gateway from private zones","direction":"INGRESS","protocol":"6","source":"10.10.0.0/16","sourceType":"CIDR_BLOCK","tcpOptions":{"destinationPortRange":{"min":8443,"max":8443}}},
    {"description":"ziti controller api admin","direction":"INGRESS","protocol":"6","source":"'$MY_IP'","sourceType":"CIDR_BLOCK","tcpOptions":{"destinationPortRange":{"min":1280,"max":1280}}},
    {"description":"ziti edge router (public+private dial)","direction":"INGRESS","protocol":"6","source":"0.0.0.0/0","sourceType":"CIDR_BLOCK","tcpOptions":{"destinationPortRange":{"min":3022,"max":3022}}},
    {"description":"egress allow-all (route tables still gate internet)","direction":"EGRESS","protocol":"all","destination":"0.0.0.0/0","destinationType":"CIDR_BLOCK"}
  ]' >/dev/null
  echo "gw rules added"
else
  echo "GW_NSG=existing:$GW_NSG"
fi

echo "== create/find spike-wl-nsg =="
WL_NSG=$(oci network nsg list -c "$C" --all --query "data[?\"display-name\"=='spike-wl-nsg'].id | [0]" --raw-output 2>/dev/null || true)
if [ -z "$WL_NSG" ] || [ "$WL_NSG" = "null" ]; then
  WL_NSG=$(oci network nsg create -c "$C" --vcn-id "$VCN_ID" --display-name spike-wl-nsg --query 'data.id' --raw-output)
  echo "WL_NSG=new:$WL_NSG"
  oci network nsg rules add --nsg-id "$WL_NSG" --security-rules '[
    {"description":"ssh bastion via edge host","direction":"INGRESS","protocol":"6","source":"10.10.10.0/24","sourceType":"CIDR_BLOCK","tcpOptions":{"destinationPortRange":{"min":22,"max":22}}},
    {"description":"egress allow-all (route tables still gate internet)","direction":"EGRESS","protocol":"all","destination":"0.0.0.0/0","destinationType":"CIDR_BLOCK"}
  ]' >/dev/null
  echo "wl rules added"
else
  echo "WL_NSG=existing:$WL_NSG"
fi

# Shape pivot: VM.Standard.E2.1.Micro was persistently "Out of host capacity"
# in eu-madrid-1-AD-1 (8 retries x 2 instances failed, 2026-08-22).
# A1.Flex (ARM64) is the free-tier alternative and matches the future
# cluster node arch (SPIKE-COMP-01/SPIKE-RT-01). 1 OCPU / 2 GB each,
# 2 OCPU / 4 GB of the 4 OCPU / 24 GB budget, destroyed at spike close.
SHAPE=${SPIKE_SHAPE:-VM.Standard.A1.Flex}
SHAPE_CONFIG=${SPIKE_SHAPE_CONFIG:-'{"ocpus":1,"memoryInGBs":2}'}
IMG=ocid1.image.oc1.eu-madrid-1.aaaaaaaasledoevbkgyyvqzjcwvj77lpsmn2bcdaieg7kevjfta66mrugqva
echo "SHAPE=$SHAPE (Oracle-Linux-9.8-aarch64-2026.08.14-0, A1-valid)"

echo "== launch micro-1 (edge-gw, public) =="
GW_INST=""
for i in $(seq 1 5); do
  ERR=$(mktemp)
  GW_INST=$(oci compute instance launch -c "$C" --availability-domain "$AD" --shape "$SHAPE" --shape-config "$SHAPE_CONFIG" \
    --subnet-id "$EDGE_SUBNET" --image-id "$IMG" --assign-public-ip true \
    --display-name spike-egress-gw --nsg-ids "[\"$GW_NSG\"]" \
    --metadata "{\"ssh_authorized_keys\": \"$KEY\"}" --query 'data.id' --raw-output 2>"$ERR" || true)
  if [ -n "$GW_INST" ] && [ "$GW_INST" != "null" ]; then
    echo "micro-1 launched on attempt $i"
    break
  fi
  echo "micro-1 attempt $i failed: $(grep -o '"message": *"[^"]*"' "$ERR" | head -1)"
  sleep 20
done
[ -z "$GW_INST" ] || [ "$GW_INST" = "null" ] && { echo "FATAL: micro-1 could not be launched (capacity)."; exit 1; }
echo "GW_INST=$GW_INST"

echo "== launch micro-2 (wl-test, private) =="
WL_INST=""
for i in $(seq 1 5); do
  ERR=$(mktemp)
  WL_INST=$(oci compute instance launch -c "$C" --availability-domain "$AD" --shape "$SHAPE" --shape-config "$SHAPE_CONFIG" \
    --subnet-id "$WL_SUBNET" --image-id "$IMG" --assign-public-ip false \
    --display-name spike-egress-wl --nsg-ids "[\"$WL_NSG\"]" \
    --metadata "{\"ssh_authorized_keys\": \"$KEY\"}" --query 'data.id' --raw-output 2>"$ERR" || true)
  if [ -n "$WL_INST" ] && [ "$WL_INST" != "null" ]; then
    echo "micro-2 launched on attempt $i"
    break
  fi
  echo "micro-2 attempt $i failed: $(grep -o '"message": *"[^"]*"' "$ERR" | head -1)"
  sleep 20
done
[ -z "$WL_INST" ] || [ "$WL_INST" = "null" ] && { echo "FATAL: micro-2 could not be launched (capacity)."; exit 1; }
echo "WL_INST=$WL_INST"

echo "== wait for RUNNING =="
for i in $(seq 1 30); do
  S1=$(oci compute instance get --instance-id "$GW_INST" --query 'data."lifecycle-state"' --raw-output 2>/dev/null || echo provisioning)
  S2=$(oci compute instance get --instance-id "$WL_INST" --query 'data."lifecycle-state"' --raw-output 2>/dev/null || echo provisioning)
  echo "  gw=$S1 wl=$S2"
  [ "$S1" = RUNNING ] && [ "$S2" = RUNNING ] && break
  sleep 10
done

echo "== public IP of micro-1 =="
oci compute instance list-vnics --instance-id "$GW_INST" --query 'data[0]."public-ip"' --raw-output

echo "== save state =="
cat > /tmp/spike-egress-state.env <<EOF
GW_INST=$GW_INST
WL_INST=$WL_INST
GW_NSG=$GW_NSG
WL_NSG=$WL_NSG
VCN_ID=$VCN_ID
EOF
echo "state saved to /tmp/spike-egress-state.env"
