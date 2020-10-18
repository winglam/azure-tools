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
runclasses="$3"
line=$(head -n 1 $projfile)

echo "================Starting experiment for input: $line"
slug=$(echo ${line} | cut -d',' -f1 | rev | cut -d'/' -f1-2 | rev)
sha=$(echo ${line} | cut -d',' -f2)
module=$(echo ${line} | cut -d',' -f3)

MVNOPTIONS="-Ddependency-check.skip=true -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip -Dcobertura.skip=true -Dfindbugs.skip=true"

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"

# echo "================Cloning the project"
bash $dir/clone-project.sh "$slug" "$sha"
cd ~/$slug

if [[ -z $module ]]; then
    echo "================ Missing module. Exiting now!"
    exit 1
else
    echo "Module passed in from csv."
fi
echo "Location of module: $module"

# echo "================Installing the project"
bash $dir/install-project.sh "$slug" "$MVNOPTIONS" "$USER" "$module" "$sha" "$dir" "$fullTestName" "${RESULTSDIR}"
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

echo "================Setup testrunner"
cd $dir
git clone https://github.com/TestingResearchIllinois/testrunner.git
cd testrunner
ifsha=$(git rev-parse HEAD)
echo "testrunner sha: $ifsha"
mvn install -DskipTests |& tee install-testrunner.log

mv install-testrunner.log ${RESULTSDIR}

echo "================Setup and run iDFlakies"
cd ~/$slug
bash $dir/idflakies-pom-modify/modify-project.sh . "1.0.2" "1.1-SNAPSHOT"

modified_module=$(echo ${module} | cut -d'.' -f2- | cut -c 2- | sed 's/\//+/g')
modified_slug_module="${modifiedslug_with_sha}=${modified_module}"
if [[ "$runclasses" == "tests" ]]; then
    permInputFile="$dir/module-summarylistgen-idempotent/${modified_slug_module}_output.csv"
else
    permInputFile="$dir/module-summarylistgen/${modified_slug_module}_output.csv"
fi

if [[ "$runclasses" == "classes" ]]; then
    # generate a file of just test classes if we are just running classes
    permClassFile="$(echo $permInputFile | rev | cut -d'/' -f2- | rev)/${modified_slug_module}_classes_output.csv"
    rev $permInputFile | cut -d'.' -f2- | rev | sort -u > $permClassFile
else
    permClassFile="$permInputFile"
fi

IDF_OPTIONS="-Ddt.detector.original_order.all_must_pass=false -Ddt.randomize.rounds=0 -Ddt.detector.original_order.retry_count=1 -Dtestplugin.runner.idempotent.num.runs=${rounds}"
for f in $(cat $permClassFile); do
    echo "Running idempotent for test: $f"

    rm -rf $module/.dtfixingtools
    mkdir -p $module/.dtfixingtools

    if [[ "$runclasses" == "classes" ]]; then
	grep ^${f}. $permInputFile  > $module/.dtfixingtools/original-order
    else
	echo $f > $module/.dtfixingtools/original-order
    fi

    timeout 2h mvn testrunner:testplugin ${MVNOPTIONS} ${IDF_OPTIONS} -pl $module -Ddetector.detector_type=original |& tee original.log

    mkdir -p ${RESULTSDIR}/idem/$f
    mv original.log ${RESULTSDIR}/idem/$f/
    mv $module/.dtfixingtools ${RESULTSDIR}/idem/$f/dtfixingtools
done

cp $permInputFile ${RESULTSDIR}/
cp $permClassFile ${RESULTSDIR}/

endtime=$(date)
echo "endtime: $endtime"
