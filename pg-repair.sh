#!/bin/bash

# Get all lines with "inconsistent" PGs and filter properly formatted PG IDs (e.g., 71.1f8)
pgs=$(ceph health detail | grep "inconsistent" | awk '{print $2}' | grep -E '^[0-9a-f]+\.[0-9a-f]+$' | sort | uniq)

if [ -z "$pgs" ]; then
  echo "No inconsistent PGs found."
  exit 0
fi

echo "Found inconsistent PGs:"
echo "$pgs"

# Loop over each valid PG and issue repair
for pg in $pgs; do
  echo "Repairing PG: $pg"
  ceph pg repair "$pg"
done

echo "Repair commands issued. Monitor with 'ceph -s' or 'ceph health detail'."
