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
pool_id=$4
line=$(head -n 1 $projfile)

echo "================Starting experiment for input: $line"
slug=$(echo ${line} | cut -d',' -f1 | rev | cut -d'/' -f1-2 | rev)
sha=$(echo ${line} | cut -d',' -f2)

fullTestName="running.idempotent"
module=$(echo ${line} | cut -d',' -f3)
modified_module=$(echo ${module} | cut -d'.' -f2- | cut -c 2- | sed 's/\//+/g')

MVNOPTIONS="-Ddependency-check.skip=true -Dmaven.repo.local=$AZ_BATCH_TASK_WORKING_DIR/$input_container/dependencies -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip -Dcobertura.skip=true -Dfindbugs.skip=true"

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"

# echo "================Cloning the project"
bash $dir/clone-project.sh "$slug" "${modifiedslug_with_sha}=${modified_module}" "$input_container"
cd ~/$slug

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
mvn compile ${MVNOPTIONS} --log-file=$AZ_BATCH_TASK_WORKING_DIR/"com=${modifiedslug_with_sha}=${modified_module}".txt

cd ~/

case `grep -q '\[INFO\] BUILD SUCCESS' "com=$modifiedslug_with_sha=$modified_module".txt ; echo $?` in
  0)
    echo "com=${modifiedslug_with_sha}=${modified_module} is compiled successfully." | tee -a /$AZ_BATCH_TASK_WORKING_DIR/$input_container/"$pool_id-results".txt
    ;;
  1)
    echo "com=${modifiedslug_with_sha}=${modified_module} is failed." | tee -a $AZ_BATCH_TASK_WORKING_DIR/$input_container/"$pool_id-results".txt
    ;;
esac

if [[ ! -f "$AZ_BATCH_TASK_WORKING_DIR/$input_container/"${modifiedslug_with_sha}=${modified_module}".zip" ]]; then
    zip -r "${modifiedslug_with_sha}=${modified_module}".zip ${slug%/*}
    cp "${modifiedslug_with_sha}=${modified_module}".zip ~/$input_container
fi

endtime=$(date)
echo "endtime: $endtime"