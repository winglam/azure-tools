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

start=$(echo $line | cut -d, -f4)
end=$(echo $line | cut -d, -f5)

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"
modified_module=$(echo ${module} | sed 's?\./??g' | sed 's/\//+/g')
modified_slug_module="${modifiedslug_with_sha}=${modified_module}"

MVNOPTIONS="-Ddependency-check.skip=true -Dmaven.repo.local=$AZ_BATCH_TASK_WORKING_DIR/dependencies/dependencies_${modified_slug_module} -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip -Dcobertura.skip=true -Dfindbugs.skip=true"

# echo "================Cloning the project"
bash $dir/clone-project.sh "$slug" "$modified_slug_module" "$input_container"
ret=${PIPESTATUS[0]}
if [[ $ret != 0 ]]; then
    if [[ $ret == 2 ]]; then
        echo "Couldn't download the project. Actual: $ret"
        exit 1
    elif [[ $ret == 1 ]]; then
        cd ~/
        rm -rf ${slug%/*}
        wget "https://github.com/$slug/archive/$sha".zip
        ret=${PIPESTATUS[0]}
        if [[ $ret != 0 ]]; then
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
        echo "Compilation failed. Actual: $ret"
        exit 1   
    fi  
fi

cd ~/$slug

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

echo "================Setup and run iDFlakies"
cd $dir
git clone https://github.com/ChopinLi-cp/simulation.git
cd simulation/iDFlakies
idfsha=$(git rev-parse HEAD)
echo "idflakies sha: $idfsha"
mvn install -DskipTests |& tee install-idflakies.log
mv install-idflakies.log ${RESULTSDIR}

echo "================Setup and run iDFlakies: $(date)"
cd ~/$slug
bash $dir/simulation/iDFlakies/pom-modify/modify-project.sh . "idflakies-maven-plugin" "2.0.1-SNAPSHOT"

IDF_OPTIONS="-Ddt.detector.roundsemantics.total=true -Ddt.randomize.rounds=0 -Ddt.detector.original_order.all_must_pass=false -Ddt.verify.rounds=0 -Ddependency-check.skip=true -Denforcer.skip=true -Drat.skip=true -Dmdep.analyze.skip=true -Dmaven.javadoc.skip=true -Dgpg.skip -Dlicense.skip=true -Dcheckstyle.skip=true -Dmaven.test.failure.ignore=true -Ddetector.detector_type=tuscan-inter-class -Ddt.randomize.rounds=2147483647 -Ddt.detector.rounds.startIndex=$start -Ddt.detector.rounds.endIndex=$end"
rm -rf $module/.dtfixingtools/
mkdir -p $module/.dtfixingtools

mvn idflakies:detect ${MVNOPTIONS} ${IDF_OPTIONS} -pl $module |& tee original.log

mkdir -p ${RESULTSDIR}/perm/
mv original.log ${RESULTSDIR}/perm/
mv $module/.dtfixingtools ${RESULTSDIR}/perm/dtfixingtools

endtime=$(date)
echo "endtime: $endtime"
