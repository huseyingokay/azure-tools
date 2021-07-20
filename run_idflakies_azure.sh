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

RESULTSDIR=~/output/
mkdir -p ${RESULTSDIR}

cd ~/
projfile=$1
rounds=$2
input_container=$3
line=$(head -n 1 $projfile)

echo "================Starting experiment for input: $line"
slug=$(echo ${line} | cut -d',' -f1 | rev | cut -d'/' -f1-2 | rev)
sha=$(echo ${line} | cut -d',' -f2)
module=$(echo ${line} | cut -d',' -f3)

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"
modified_module=$(echo ${module} | sed 's?\./??g' | sed 's/\//+/g')
modified_slug_module="${modifiedslug_with_sha}=${modified_module}"

MVNOPTIONS="-Ddependency-check.skip=true -Dmaven.repo.local=$AZ_BATCH_TASK_WORKING_DIR/dependencies_${modifiedslug_with_sha}=${modified_module} -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip -Dcobertura.skip=true -Dfindbugs.skip=true"

# echo "================Cloning the project"
bash $dir/clone-project.sh "$slug" "$modified_slug_module" "$input_container"
ret=${PIPESTATUS[0]}
if [[ $ret != 0 ]]; then
    if [[ $ret == 2 ]]; then
        echo "$line,${modifiedslug_with_sha}=${modified_module},cannot_clone" >> $AZ_BATCH_TASK_WORKING_DIR/$input_container/results/"${modifiedslug_with_sha}=${modified_module}-results".csv
        echo "Couldn't download the project. Actual: $ret"
        exit 1
    elif [[ $ret == 1 ]]; then
        cd ~/
        wget "https://github.com/$slug/archive/$sha".zip
        ret=${PIPESTATUS[0]}
        if [[ $ret != 0 ]]; then
            echo "$line,${modifiedslug_with_sha}=${modified_module},cannot_checkout_or_wget" >> $AZ_BATCH_TASK_WORKING_DIR/$input_container/results/"${modifiedslug_with_sha}=${modified_module}-results".csv
            echo "Compilation failed. Actual: $ret"
            exit 1
        else
            echo "git checkout failed but wget successfully downloaded the project and sha, proceeding to the rest of this script"
            bash $dir/install-project.sh "$slug" "$MVNOPTIONS" "$USER" "$module" "$sha" "$dir" "$fullTestName" "${RESULTSDIR}" "$input_container"
            ret=${PIPESTATUS[0]}
            cd ~/

            mkdir -p $AZ_BATCH_TASK_WORKING_DIR/$input_container/results

            if [[ $ret != 0 ]]; then 
                echo "$line,${modifiedslug_with_sha}=${modified_module},failed_wget" >> $AZ_BATCH_TASK_WORKING_DIR/$input_container/results/"${modifiedslug_with_sha}=${modified_module}-results".csv
                exit 0
            else
                echo "$line,${modifiedslug_with_sha}=${modified_module},passed_wget" >> $AZ_BATCH_TASK_WORKING_DIR/$input_container/results/"${modifiedslug_with_sha}=${modified_module}-results".csv
                exit 0
            fi
        fi
    else
        echo "Compilation failed. Actual: $ret"
        exit 1   
    fi  
fi

if [[ -z $module ]]; then
    echo "================ Missing module. Exiting now!"
    exit 1
else
    echo "Module passed in from csv."
fi
echo "Location of module: $module"

# echo "================Installing the project"
bash $dir/install-project.sh "$slug" "$MVNOPTIONS" "$USER" "$module" "$sha" "$dir" "$fullTestName" "${RESULTSDIR}" "$input_container"
ret=${PIPESTATUS[0]}
mv mvn-install.log ${RESULTSDIR}
if [[ $ret != 0 ]]; then
    # mvn install does not compile - return 0
    echo "Compilation failed. Actual: $ret"
    exit 1
fi

# echo "================Running maven test"
if [[ "$slug" == "dropwizard/dropwizard" ]]; then
    # dropwizard module complains about missing dependency if one uses -pl for some modules. e.g., ./dropwizard-logging
    MVNOPTIONS="${MVNOPTIONS} -am"
elif [[ "$slug" == "fhoeben/hsac-fitnesse-fixtures" ]]; then
    MVNOPTIONS="${MVNOPTIONS} -DskipITs"
fi

echo "================Clone and run JVM/JPF"
cd $dir
git clone https://github.com/y553546436/JPF_Homework.git
cd $dir/JPF_Homework/algo
jpfdir=$(pwd)
sha=$(git rev-parse HEAD)
echo "JPF_Homework sha: $sha"

javac testOrder.java

echo "================Setup and run iDFlakies"
cd ~/$slug
bash $dir/idflakies-pom-modify/modify-project.sh .


permInputFile="$dir/module-summarylistgen/${modified_slug_module}_output.csv"

# permInputFile should be used to create the contents of permDir
permDir="$dir/${modified_slug_module}_input"
mkdir -p $permDir

java -cp $jpfdir testOrder $permInputFile 1 1 > ${RESULTSDIR}/testOrder.out

i=1;
for f in $(cat ${RESULTSDIR}/testOrder.out); do
    echo $f | sed 's/,/\n/g' > $permDir/$i.txt;
    i=$((i+1));
done

IDF_OPTIONS="-Ddt.detector.original_order.all_must_pass=false -Ddt.randomize.rounds=${rounds} -Ddt.detector.original_order.retry_count=1"
for f in $(find $permDir -name "*.txt"); do
    echo "Running permutation: $f"
    fn=$(echo $f | rev | cut -d'/' -f1 | rev);
    rm -rf $module/.dtfixingtools/
    mkdir -p $module/.dtfixingtools
    cp -r $f $module/.dtfixingtools/original-order

    timeout 2h mvn testrunner:testplugin ${MVNOPTIONS} ${IDF_OPTIONS} -pl $module -Ddetector.detector_type=original |& tee original.log

    mkdir -p ${RESULTSDIR}/perm/$fn
    mv original.log ${RESULTSDIR}/perm/$fn/
    mv $module/.dtfixingtools ${RESULTSDIR}/perm/$fn/dtfixingtools
done

cp $permInputFile ${RESULTSDIR}/

endtime=$(date)
echo "endtime: $endtime"
