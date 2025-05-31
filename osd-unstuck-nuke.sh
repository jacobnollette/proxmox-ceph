#!/bin/bash
# Script: remote-restart-stuck-osds.sh
# Description: Restart OSDs involved in PGs stuck on deep-scrub, grouped by host

set -euo pipefail

declare -A HOST_OSDS

echo "[*] Gathering PGs not deep-scrubbed..."
PGS=$(ceph health detail | grep 'not deep-scrubbed since' | awk '{print $2}' | sort -u)

echo "[*] Mapping PGs to OSDs..."
OSD_LIST=()
for pg in $PGS; do
    ACTING=$(ceph pg map "$pg" | awk -F'[][]' '{print $2}')
    for osd in $(echo "$ACTING" | tr ',' ' '); do
        OSD_LIST+=("$osd")
    done
done

UNIQUE_OSDS=$(echo "${OSD_LIST[@]}" | tr ' ' '\n' | sort -n | uniq)

echo "[*] Mapping OSDs to hosts..."
for osd in $UNIQUE_OSDS; do
    host=$(ceph osd find "$osd" -f json | jq -r '.crush_location.host')
    HOST_OSDS["$host"]+="$osd "
done

echo "[*] Restarting OSDs per host..."
for host in "${!HOST_OSDS[@]}"; do
    osds=${HOST_OSDS[$host]}
    echo "  ↻ Host: $host → OSDs: $osds"

    ssh -o BatchMode=yes root@"$host" bash -c "'
        set -e
        for osd in $osds; do
            echo \"    ↺ Restarting ceph-osd@\$osd\"
            systemctl restart ceph-osd@\$osd
            sleep 2
        done
    '"
done

echo "[✔] Done. Check progress with: ceph -w"
