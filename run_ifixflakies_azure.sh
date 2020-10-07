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
line=$(head -n 1 $projfile)

echo "================Starting experiment for input: $line"
slug=$(echo ${line} | cut -d',' -f1 | rev | cut -d'/' -f1-2 | rev)
sha=$(echo ${line} | cut -d',' -f2)
test=$(echo ${line} | cut -d',' -f3)
module=$(echo ${line} | cut -d',' -f4)

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

echo "================Clone and setup iFixFlakies"
cd $dir
git clone https://github.com/TestingResearchIllinois/iFixFlakies.git
cd $dir/iFixFlakies
ifdir=$(pwd)
mvn install -DskipTests
ifsha=$(git rev-parse HEAD)
echo "ifixflakies sha: $ifsha"

echo "================Run iFixFlakies"

cd ~/$slug
bash $ifdir/pom-modify/modify-project.sh .

modified_module=$(echo ${module} | cut -d'.' -f2- | cut -c 2- | sed 's/\//+/g')
modified_slug_module="${modifiedslug_with_sha}=${modified_module}"
permInputFile="$dir/module-summarylistgen/${modified_slug_module}_output.csv"
json_file="$dir/flaky-lists-jsons/${modifiedslug_with_sha}=${test}_output.json"

mvn testrunner:testplugin ${MVNOPTIONS} -pl $module -Ddt.minimizer.use.original.order=true -Ddt.minimizer.flaky.list=${json_file} -Ddt.minimizer.original.order=${permInputFile} -Ddt.minimizer.dependent.test=${test} -Ddiagnosis.run_detection=false -Dtestplugin.className=edu.illinois.cs.dt.tools.minimizer.MinimizerPlugin -Ddt.minimizer.polluters.one_by_one=true -Dtestplugin.runner.use_timeout=false |& tee minimizer.log

mkdir -p ${RESULTSDIR}/minimizer/
mv minimizer.log ${RESULTSDIR}/minimizer/
mv $module/.dtfixingtools ${RESULTSDIR}/minimizer/dtfixingtools
cp $permInputFile ${RESULTSDIR}/
cp $json_file ${RESULTSDIR}/

endtime=$(date)
echo "endtime: $endtime"
