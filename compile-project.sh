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

# echo "================Cloning the project"
bash /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1/azure-tools/clone-project.sh "$slug" "$modified_slug_module" "$input_container"
ret_clone_project=${PIPESTATUS[0]}
if [[ $ret_clone_project != 0 ]]; then
    if [[ $ret_clone_project == 2 ]]; then
        echo "$line,$modified_slug_module,cannot_clone" >> /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1/$input_container/results/"${modified_slug_module}-results".csv
        echo "Couldn't download the project. Actual: $ret_clone_project"
        exit 1
    elif [[ $ret_clone_project == 1 ]]; then
        cd /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1
        rm -rf ${slug%/*}
        wget "https://github.com/$slug/archive/$sha".zip
        ret=${PIPESTATUS[0]}
        if [[ $ret != 0 ]]; then
            echo "$line,$modified_slug_module,cannot_checkout_or_wget" >> /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1/$input_container/results/"${modified_slug_module}-results".csv
            echo "Compilation failed. Actual: $ret"
            exit 1
        else
            echo "git checkout failed but wget successfully downloaded the project and sha, proceeding to the rest of this script"
            mkdir -p $slug
            unzip -q $sha -d $slug
            cd $slug/*
            to_be_deleted=${PWD##*/}  
            mv * ../
            cd ../
            rm -rf $to_be_deleted  
        fi
    else
        echo "Compilation failed. Actual: $ret_clone_project"
        exit 1   
    fi  
fi

cd /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1/$slug

# echo "================Installing the project"
if [[ -z $module ]]; then
    module=$classloc
    while [[ "$module" != "." && "$module" != "" ]]; do
	module=$(echo $module | rev | cut -d'/' -f2- | rev)
	echo "Checking for pom at: $module"
	if [[ -f $module/pom.xml ]]; then
	    break;
	fi
    done
else
    echo "Module passed in from csv."
fi
echo "Location of module: $module"

if [[ "$slug" == "dropwizard/dropwizard" ]]; then
    # dropwizard module complains about missing dependency if one uses -pl for some modules. e.g., ./dropwizard-logging
    MVNOPTIONS="${MVNOPTIONS} -am"
elif [[ "$slug" == "fhoeben/hsac-fitnesse-fixtures" ]]; then
    MVNOPTIONS="${MVNOPTIONS} -DskipITs"
fi

echo "================Compiling: $(date)"
bash $dir/install-project.sh "$slug" "$MVNOPTIONS" "$USER" "$module" "$sha" "$dir" "$fullTestName" "${RESULTSDIR}" "$input_container"
ret=${PIPESTATUS[0]}
cd /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1

mkdir -p /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1/$input_container/results
if [[ $ret_clone_project != 0 ]]; then
    if [[ $ret != 0 ]]; then 
        echo "$line,$modified_slug_module,failed_wget" >> /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1/$input_container/results/"${modified_slug_module}-results".csv
    else
        echo "$line,$modified_slug_module,passed_wget" >> /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1/$input_container/results/"${modified_slug_module}-results".csv
    fi
else
    if [[ $ret != 0 ]]; then 
        echo "$line,$modified_slug_module,failed" >> /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1/$input_container/results/"${modified_slug_module}-results".csv
    else
        echo "$line,$modified_slug_module,passed" >> /mnt/batch/tasks/workitems/SUA_tmp_r2_7M21d18h23m34s/job-1/$input_container/results/"${modified_slug_module}-results".csv
    fi
fi
endtime=$(date)
echo "endtime: $endtime"
