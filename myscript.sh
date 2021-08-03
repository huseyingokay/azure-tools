#!/bin/bash

for f in $(find /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1/rtp-passed-psms/failed -name *.csv); do
  filename=$(echo $f | rev | cut -d'.' -f2- | rev);
  bash compile-project.sh ${f} 2 inputcompiletest SUA_tmp_r2_7M21d18h23m34s None &>> ${filename}.out;
done

