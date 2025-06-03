#!/bin/bash

# Get all lines with "inconsistent" PGs and filter properly formatted PG IDs (e.g., 71.1f8)
pgs=$(ceph health detail | grep "inconsistent" | awk '{print $2}' | grep -E '^[0-9a-f]+\.[0-9a-f]+$' | sort | uniq)

if [ -z "$pgs" ]; then
  echo "No inconsistent PGs found."
  exit 0
fi

echo "Found inconsistent PGs:"
echo "$pgs"

# Track scrubbed OSDs to avoid duplicate scrubs
scrubbed_osds=()

# Loop over each valid PG
for pg in $pgs; do
  echo "Repairing PG: $pg"
  ceph pg repair "$pg"

  # Get the OSDs hosting this PG
  osds=$(ceph pg map "$pg" | grep -oP 'acting \[\K[^\]]+')

  echo "OSDs for PG $pg: $osds"

  # Issue a deep-scrub to each involved OSD if not already scrubbed
  for osd in $(echo "$osds" | tr ',' ' '); do
    if [[ ! " ${scrubbed_osds[@]} " =~ " $osd " ]]; then
      echo "Issuing deep-scrub on OSD $osd"
      ceph osd deep-scrub "$osd"
      scrubbed_osds+=("$osd")
    else
      echo "OSD $osd already scrubbed. Skipping."
    fi
  done
done

echo "Repair and scrub commands issued. Monitor with 'ceph -s' or 'ceph health detail'."
