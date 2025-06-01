#!/bin/bash

for pg in $(ceph health detail | grep 'not deep-scrubbed' | awk '{print $2}'); do
  ceph pg deep-scrub $pg
done
