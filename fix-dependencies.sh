#!/bin/bash

if [[ $1 == "" ]]; then
    echo "arg1 - Path to CSV file with project,sha,test"
    exit
fi

repo=$(git rev-parse HEAD)
echo "script vers: $repo"
dir=/mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1/azure-tools
echo "script dir: $dir"
starttime=$(date)
echo "starttime: $starttime"

cd /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1
projfile=$1
rounds=$2
input_container=$3
pool_id=$4
line=$(head -n 1 $projfile)

echo "================Starting experiment for input: $line"
slug=$(echo ${line} | cut -d',' -f1 | rev | cut -d'/' -f1-2 | rev)
sha=$(echo ${line} | cut -d',' -f2)

fullTestName="running.idempotent"
module=$(echo ${line} | cut -d',' -f3)
modified_module=$(echo ${module} | sed 's?\./??g' | sed 's/\//+/g')

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"
modified_slug_module="${modifiedslug_with_sha}=${modified_module}"

MVNOPTIONS="-Ddependency-check.skip=true -Dmaven.repo.local=/mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1/dependencies_$modified_slug_module -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip -Dcobertura.skip=true -Dfindbugs.skip=true"

cd /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1
if [[ ! -d "dependencies_${modified_slug_module}" ]] && [[ -f "${input_container}/dependencies_${modified_slug_module}.zip" ]]; then
    cp $input_container/dependencies_${modified_slug_module}.zip .
    unzip -q dependencies_${modified_slug_module}.zip

    echo "$modified_slug_sha_module already exists in the container"
    cp $input_container/projects/${modified_slug_module}.zip .
    unzip -q ${modified_slug_module}.zip
    cd $slug
    echo "SHA is $(git rev-parse HEAD)"
    ret_clone_project=0
else
    echo "================ cannot find zip file for $line"
    ret_clone_project=1
fi

if [[ "$slug" == "dropwizard/dropwizard" ]]; then
    # dropwizard module complains about missing dependency if one uses -pl for some modules. e.g., ./dropwizard-logging
    MVNOPTIONS="${MVNOPTIONS} -am"
elif [[ "$slug" == "fhoeben/hsac-fitnesse-fixtures" ]]; then
    MVNOPTIONS="${MVNOPTIONS} -DskipITs"
fi

new_input_container=?? # FILL THIS IN
if [[ $ret_clone_project == 0 ]]; then
    echo "================Compiling: $(date)"
    bash $dir/test-project.sh "$slug" "$MVNOPTIONS" "$USER" "$module" "$sha" "$dir" "$fullTestName" "${RESULTSDIR}" "$new_input_container"
    ret=${PIPESTATUS[0]}
fi
cd /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1

mkdir -p /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1/${new_input_container}/results
if [[ $ret_clone_project != 0 ]]; then
    echo "$line,$modified_slug_module,failed_get_zip" >> /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1/${new_input_container}/results/"${modified_slug_module}-results".csv
else
    if [[ $ret != 0 ]]; then 
        echo "$line,$modified_slug_module,failed_update" >> /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1/${new_input_container}/results/"${modified_slug_module}-results".csv
    else
        echo "$line,$modified_slug_module,passed_update" >> /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1/${new_input_container}/results/"${modified_slug_module}-results".csv
    fi
fi

endtime=$(date)
echo "endtime: $endtime"
