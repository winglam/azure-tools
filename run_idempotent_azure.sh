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
runclasses="$4"
line=$(head -n 1 $projfile)

echo "================Starting experiment for input: $line"
slug=$(echo ${line} | cut -d',' -f1 | rev | cut -d'/' -f1-2 | rev)
sha=$(echo ${line} | cut -d',' -f2)
module=$(echo ${line} | cut -d',' -f3)

MVNOPTIONS="-Ddependency-check.skip=true -Dmaven.repo.local=$AZ_BATCH_TASK_WORKING_DIR/$input_container/dependencies -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip -Dcobertura.skip=true -Dfindbugs.skip=true"

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"
modified_module=$(echo ${module} | cut -d'.' -f2- | cut -c 2- | sed 's/\//+/g')
modified_slug_module="${modifiedslug_with_sha}=${modified_module}"

# echo "================Cloning the project"
bash $dir/clone-project.sh "$slug" "$modified_slug_module"
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

echo "================Setup testrunner: $(date)"
cd $dir
git clone https://github.com/TestingResearchIllinois/testrunner.git
cd testrunner

# to hide changes from double blind
wget http://mir.cs.illinois.edu/winglam/personal/idflakies-testrunner-ni-changes.diff
git apply idflakies-testrunner-ni-changes.diff
echo "====testrunner changes:"
git diff

ifsha=$(git rev-parse HEAD)
echo "testrunner sha: $ifsha"
mvn install -DskipTests |& tee install-testrunner.log
mv install-testrunner.log ${RESULTSDIR}

cd $dir
git clone https://github.com/idflakies/iDFlakies.git
cd iDFlakies
idfsha=$(git rev-parse HEAD)
echo "idflakies sha: $idfsha"
mvn install -DskipTests |& tee install-idflakies.log
mv install-idflakies.log ${RESULTSDIR}

echo "================Setup and run iDFlakies: $(date)"
cd ~/$slug
bash $dir/idflakies-pom-modify/modify-project.sh . "1.2.0-SNAPSHOT" "1.3-SNAPSHOT"


if [[ "$runclasses" == "tests" ]]; then
    # Verify some found NI tests
    permInputFile="$dir/module-summarylistgen-idempotent/${modified_slug_module}_output.csv"
else
    permInputFile="$dir/module-summarylistgen/${modified_slug_module}_output.csv"
fi

if [[ "$runclasses" == "classes" ]]; then
    # generate a file of just test classes if we are just running classes
    permClassFile="$(echo $permInputFile | rev | cut -d'/' -f2- | rev)/${modified_slug_module}_classes_output.csv"
    rev $permInputFile | cut -d'.' -f2- | rev | sort -u > $permClassFile
elif [[ "$runclasses" == "suite" ]] || [[ "$runclasses" == "psuite" ]]; then
    # create a dummy file with just one line to run the upcoming loop once
    permClassFile="some_dummy_file"
    echo "." > $permClassFile
else
    permClassFile="$permInputFile"
fi

echo "================Running iDFlakies: $(date)" 
IDF_OPTIONS="-Ddt.detector.original_order.all_must_pass=false -Ddt.randomize.rounds=0 -Ddt.detector.original_order.retry_count=1 -Dtestplugin.runner.idempotent.num.runs=${rounds} -Dtestplugin.runner.consec.idempotent=true -Ddt.detector.forceJUnit4=true"
for f in $(cat $permClassFile); do
    echo "Running idempotent for test: $f"

    rm -rf $module/.dtfixingtools
    mkdir -p $module/.dtfixingtools

    timeout="2h"
    if [[ "$runclasses" == "classes" ]]; then
	grep "^${f}\." $permInputFile  > $module/.dtfixingtools/original-order
	timeout="24h"
    elif [[ "$runclasses" == "suite" ]]; then
	cat $permInputFile  > $module/.dtfixingtools/original-order
	timeout="48h"
    else
	echo $f > $module/.dtfixingtools/original-order
    fi

    if [[ "$runclasses" == "psuite" ]]; then
	# rely on iDFlakies to generate test order
	for f in $(find -name .dtfixingtools); do rm -rf $f; done
	echo "running psuite; leaving original-order untouched"
	timeout $timeout mvn testrunner:testplugin ${MVNOPTIONS} ${IDF_OPTIONS} -Ddetector.detector_type=original |& tee original.log
    else
	timeout $timeout mvn testrunner:testplugin ${MVNOPTIONS} ${IDF_OPTIONS} -pl $module -Ddetector.detector_type=original |& tee original.log
    fi

    mkdir -p ${RESULTSDIR}/idem/$f
    if [[ "$runclasses" == "psuite" ]]; then
	mkdir -p ${RESULTSDIR}/idem/dtfixingtools
	for f in $(find -name .dtfixingtools); do cp --parents -r $f ${RESULTSDIR}/idem/dtfixingtools/; done
	mv original.log ${RESULTSDIR}/idem/
    else
	mv original.log ${RESULTSDIR}/idem/$f/
	mv $module/.dtfixingtools ${RESULTSDIR}/idem/$f/dtfixingtools
    fi
done

cp $permInputFile ${RESULTSDIR}/
cp $permClassFile ${RESULTSDIR}/

endtime=$(date)
echo "endtime: $endtime"
