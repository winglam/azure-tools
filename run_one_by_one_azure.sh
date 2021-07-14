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
mode="$4"
line=$(head -n 1 $projfile)

echo "================Starting experiment for input: $line"
slug=$(echo ${line} | cut -d',' -f1 | rev | cut -d'/' -f1-2 | rev)
sha=$(echo ${line} | cut -d',' -f2)

if [[ "$mode" == "idempotent" ]]; then
    fullTestName="running.idempotent"
    module=$(echo ${line} | cut -d',' -f3)
else
    fullTestName=$(echo ${line} | cut -d',' -f3)
    module=$(echo ${line} | cut -d',' -f4)
    polluter=$(echo ${line} | cut -d',' -f5)
fi
modified_module=$(echo ${module} | cut -d'.' -f2- | cut -c 2- | sed 's/\//+/g')

MVNOPTIONS="-Ddependency-check.skip=true -Dmaven.repo.local=$AZ_BATCH_TASK_WORKING_DIR/$input_container/dependencies -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip -Dcobertura.skip=true -Dfindbugs.skip=true"

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"

# echo "================Cloning the project"
bash $dir/clone-project.sh "$slug" "${modifiedslug_with_sha}=${modified_module}"
cd ~/$slug

echo "================Setting up test name"
testarg=""
if [[ $fullTestName == "-" ]] || [[ "$fullTestName" == "" ]]; then
    echo "No test name given for isolation. Exiting immediately"
    date
    exit 1
else
    formatTest="$(echo $fullTestName | rev | cut -d. -f2 | rev)#$(echo $fullTestName | rev | cut -d. -f1 | rev )"
    class="$(echo $fullTestName | rev | cut -d. -f2 | rev)"
    echo "Test name is given. Running isolation on the specific test: $formatTest"
    echo "class: $class"
    testarg="-Dtest=$formatTest"
fi

classloc=$(find -name $class.java)
if [[ "$mode" != "idempotent" ]]; then 
    if [[ -z $classloc ]]; then
	echo "exit: 100 No test class at this commit."
	exit 100
    fi
fi
classcount=$(find -name $class.java | wc -l)
if [[ "$classcount" != "1" ]]; then
    classloc=$(find -name $class.java | head -n 1)
    echo "Multiple test class found. Unsure which one to use. Choosing: $classloc. Other ones are:"
    find -name $class.java
fi

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

# echo "================Installing the project"
bash $dir/install-project.sh "$slug" "$MVNOPTIONS" "$USER" "$module" "$sha" "$dir" "$fullTestName" "${RESULTSDIR}" "$input_container"
ret=${PIPESTATUS[0]}
mv mvn-install.log ${RESULTSDIR}
if [[ $ret != 0 ]]; then
    # mvn install does not compile - return 0
    echo "Compilation failed. Actual: $ret"
    exit 1
fi

# echo "================Setting up maven-surefire"
bash $dir/setup-custom-maven-tri.sh "${RESULTSDIR}" "$dir" "$fullTestName" "$modifiedslug_with_sha" "$module"
cd ~/$slug

echo "================Setup to parse test list"
pip install BeautifulSoup4
pip install lxml

echo "================Starting OBO"
if [[ "$slug" == "dropwizard/dropwizard" ]]; then
    # dropwizard module complains about missing dependency if one uses -pl for some modules. e.g., ./dropwizard-logging
    MVNOPTIONS="${MVNOPTIONS} -am"
elif [[ "$slug" == "fhoeben/hsac-fitnesse-fixtures" ]]; then
    MVNOPTIONS="${MVNOPTIONS} -DskipITs"
fi

JMVNOPTIONS="${MVNOPTIONS} -Dsurefire.methodRunOrder=fixed -Djava.awt.headless=true -Dmaven.main.skip -DtrimStackTrace=false -Dmaven.test.failure.ignore=true"
# JMVNOPTIONS="${MVNOPTIONS} -Dsurefire.methodRunOrder=flakyfinding -Djava.awt.headless=true -Dmaven.main.skip -DtrimStackTrace=false -Dmaven.test.failure.ignore=true"
fullClass="$(echo $fullTestName | rev | cut -d. -f2- | rev)"
testName="$(echo $fullTestName | rev | cut -d. -f1 | rev )"
hashfile="${RESULTSDIR}/p-v-hash.csv"
echo "polluter,victim,hash,round_num" > $hashfile
mkdir -p ${RESULTSDIR}/pair-results
if [[ "$polluter" != "" ]]; then
    echo "Single polluter passed in: $polluter"
    for ((i=1;i<=rounds;i++)); do
	bash $dir/rounds-obo.sh "$i" "$rounds" "$polluter" "$fullTestName" "$fullClass" "$testName" "$slug" "$module" "$JMVNOPTIONS" "$dir" "$RESULTSDIR" "$hashfile" "$mode"
    done

    echo "Running victim after polluter"
    pfullClass="$(echo $polluter | rev | cut -d. -f2- | rev)"
    ptestName="$(echo $polluter | rev | cut -d. -f1 | rev )"
    for ((i=1;i<=rounds;i++)); do
	bash $dir/rounds-obo.sh "p$i" "$rounds" "$fullTestName" "$polluter" "$pfullClass" "$ptestName" "$slug" "$module" "$JMVNOPTIONS" "$dir" "$RESULTSDIR" "$hashfile" "$mode"
    done
else
    modified_module=$(echo ${module} | cut -d'.' -f2- | cut -c 2- | sed 's/\//+/g')
    if [[ "$mode" == "idempotent" ]]; then
	tl="$dir/module-summarylistgen-idempotent/${modifiedslug_with_sha}=${modified_module}_output.csv"
    else
	tl="$dir/module-summarylistgen/${modifiedslug_with_sha}=${modified_module}_output.csv"
    fi
    cp $tl ${RESULTSDIR}/
    total=$(cat $tl | wc -l)
    i=1
    for f in $(cat $tl ); do
	bash $dir/rounds-obo.sh "$i" "$total" "$f" "$fullTestName" "$fullClass" "$testName" "$slug" "$module" "$JMVNOPTIONS" "$dir" "$RESULTSDIR" "$hashfile" "$mode"
	i=$((i+1))
    done    
fi

endtime=$(date)
echo "endtime: $endtime"
