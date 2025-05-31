#!/bin/bash

LOGFILE="/var/log/ceph-osd-restarts"
TIMESTAMP=$(date '+%Y-%m-%d-%H-%M-%S')

# Get list of OSDs reporting slow operations
SLOW_OSDS=$(ceph health detail | grep -oP 'osd\.\d+' | sort -u)

# Exit if no slow OSDs are found
if [ -z "$SLOW_OSDS" ]; then
  echo "$TIMESTAMP - No slow OSDs detected." >> "$LOGFILE"
  exit 0
fi

# Loop through each OSD
for OSD in $SLOW_OSDS; do
  OSD_ID=$(echo "$OSD" | cut -d. -f2)
  
  # Determine which host the OSD is on
  HOST=$(ceph osd find "$OSD_ID" -f json | jq -r '.crush_location.host')

  if [ -z "$HOST" ]; then
    echo "$TIMESTAMP - Unable to determine host for $OSD" >> "$LOGFILE"
    continue
  fi

  # Attempt to restart the OSD remotely via SSH
  echo "$TIMESTAMP - $HOST - $OSD restarting..." >> "$LOGFILE"
  ssh "$HOST" "sudo systemctl restart ceph-osd@$OSD_ID" 2>/dev/null

  if [ $? -eq 0 ]; then
    echo "$TIMESTAMP - $HOST - $OSD restarted" >> "$LOGFILE"
  else
    echo "$TIMESTAMP - $HOST - $OSD restart FAILED" >> "$LOGFILE"
  fi
done
