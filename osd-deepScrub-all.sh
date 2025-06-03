#!/bin/bash
#
for osd in $(ceph osd ls); do
  ceph osd deep-scrub osd.$osd
done

