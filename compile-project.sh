#!/bin/bash

if [[ $1 == "" ]]; then
    echo "arg1 - Path to CSV file with project,sha,test"
    exit
fi

repo=$(git rev-parse HEAD)
echo "script vers: $repo"
dir=$(pwd)
echo "script dir: $dir"
starttime=$(date)
echo "starttime: $starttime"

cd ~/
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

MVNOPTIONS="-Ddependency-check.skip=true -Dmaven.repo.local='$AZ_BATCH_TASK_WORKING_DIR/dependencies_$modified_slug_module' -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip -Dcobertura.skip=true -Dfindbugs.skip=true"

# echo "================Cloning the project"
bash $dir/clone-project.sh "$slug" "$modified_slug_module" "$input_container"
ret=${PIPESTATUS[0]}
if [[ $ret != 0 ]]; then
    if [[ $ret == 2 ]]; then
        echo "$line,$modified_slug_module,cannot_clone" >> $AZ_BATCH_TASK_WORKING_DIR/$input_container/results/"$modified_slug_module-results".csv
        echo "Couldn't download the project. Actual: $ret"
        exit 1
    elif [[ $ret == 1 ]]; then
        cd ~/
        rm -rf ${slug%/*}
        wget "https://github.com/$slug/archive/$sha".zip
        ret=${PIPESTATUS[0]}
        if [[ $ret != 0 ]]; then
            echo "$line,$modified_slug_module,cannot_checkout_or_wget" >> $AZ_BATCH_TASK_WORKING_DIR/$input_container/results/"$modified_slug_module-results".csv
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
            echo $PWD
            bash $dir/install-project.sh "$slug" "$MVNOPTIONS" "$USER" "$module" "$sha" "$dir" "$fullTestName" "${RESULTSDIR}" "$input_container"
            ret=${PIPESTATUS[0]}

            mkdir -p $AZ_BATCH_TASK_WORKING_DIR/$input_container/results

            if [[ $ret != 0 ]]; then 
                echo "$line,$modified_slug_module,failed_wget" >> $AZ_BATCH_TASK_WORKING_DIR/$input_container/results/"$modified_slug_module-results".csv
                exit 0
            else
                echo "$line,$modified_slug_module,passed_wget" >> $AZ_BATCH_TASK_WORKING_DIR/$input_container/results/"$modified_slug_module-results".csv
                exit 0
            fi
        fi
    else
        echo "Compilation failed. Actual: $ret"
        exit 1   
    fi  
fi

cd ~/$slug
echo $PWD

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
cd ~/

mkdir -p $AZ_BATCH_TASK_WORKING_DIR/$input_container/results

if [[ $ret != 0 ]]; then 
    echo "$line,$modified_slug_module,failed" >> $AZ_BATCH_TASK_WORKING_DIR/$input_container/results/"$modified_slug_module-results".csv
else
    echo "$line,$modified_slug_module,passed" >> $AZ_BATCH_TASK_WORKING_DIR/$input_container/results/"$modified_slug_module-results".csv
fi

endtime=$(date)
echo "endtime: $endtime"
