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
fullTestName=$(echo ${line} | cut -d',' -f3)
module=$(echo ${line} | cut -d',' -f4)
polluter=$(echo ${line} | cut -d',' -f5)


MVNOPTIONS="-Ddependency-check.skip=true -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip"

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"

# echo "================Cloning the project"
bash $dir/clone-project.sh "$slug" "$sha"
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
if [[ -z $classloc ]]; then
    echo "exit: 100 No test class at this commit."
    exit 100
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
bash $dir/install-project.sh "$slug" "$MVNOPTIONS" "$USER" "$module" "$sha" "$dir"
ret=${PIPESTATUS[0]}
mv mvn-install.log ${RESULTSDIR}
if [[ $ret != 0 ]]; then
    # mvn install does not compile - return 0
    echo "Compilation failed. Actual: $ret"
    exit 1
fi

# echo "================Setting up maven-surefire"
bash $dir/setup-custom-maven.sh "${RESULTSDIR}" "$dir" "$fullTestName" "$modifiedslug_with_sha" "$module"
cd ~/$slug

echo "================Setup to parse test list"
pip install BeautifulSoup4
pip install lxml

echo "================Starting OBO"
JMVNOPTIONS="${MVNOPTIONS} -Dsurefire.methodRunOrder=flakyfinding -Djava.awt.headless=true -Dmaven.main.skip -DtrimStackTrace=false -Dmaven.test.failure.ignore=true"
fullClass="$(echo $fullTestName | rev | cut -d. -f2- | rev)"
testName="$(echo $fullTestName | rev | cut -d. -f1 | rev )"
if [[ "$polluter" == "" ]]; then
    echo "Single polluter passed in: $polltuer"
    fc="$(echo $polluter | rev | cut -d. -f2- | rev)"
    ft="$(echo $polluter | rev | cut -d. -f1 | rev)"
    testarg="-Dtest=$fc#$ft,$fullClass#$testName -DflakyTestOrder=$ft($fc),$testName($fullClass)";
    bash $dir/rounds.sh "$rounds" "$slug" "$testarg" "$JMVNOPTIONS" "$RESULTSDIR" "$module" "$dir" "$fullTestName" "$ordering" "1"
else
    tl="$dir/module-summarylistgen/${modifiedslug_with_sha}=${modified_module}_output.csv"
    total=$(cat $tl | wc -l)
    i=1
    rm -rf ${RESULTSDIR}/rounds-test-results.csv
    mkdir -p ${RESULTSDIR}/pair-results
    for f in $(cat $tl ); do
	echo "Iteration $i / $total"
	echo "Pairing $f and $fullTestName"
	find . -name TEST-*.xml -delete
	fc="$(echo $f | rev | cut -d. -f2- | rev)"
	ft="$(echo $f | rev | cut -d. -f1 | rev)"
	order="-Dtest=$fc#$ft,$fullClass#$testName -DflakyTestOrder=$ft($fc),$testName($fullClass)";
	mvn test -pl $module ${order} ${JMVNOPTIONS} |& tee mvn-test-$i-$f-$fullTestName.log

	echo "" > $i-$f-$fullTestName.csv
	for j in $(find -name "TEST*.xml"); do
	    python $dir/python-scripts/parse_surefire_report.py $j $i "" >> $i-$f-$fullTestName.csv
	done
	cp $i-$f-$fullTestName.csv ${RESULTSDIR}/pair-results

	python $dir/python-scripts/parse_obo_results.py $i-$f-$fullTestName.csv $fullTestName $f  >> ${RESULTSDIR}/rounds-test-results.csv

	didfail=$(grep -v ,pass, $i-$f-$fullTestName.csv)
	if [[ ! -z $didfail ]]; then
	    echo "RESULT at least one test failed for: $f and $fullTestName"
	    mkdir -p ${RESULTSDIR}/pairs/$i
	    mv mvn-test-$i-$f-$fullTestName.log ${RESULTSDIR}/pairs/$i
	    for g in $(find -name "TEST*.xml"); do
		mv $g ${RESULTSDIR}/pairs/$i
	    done
	else
	    echo "RESULT Both tests passed: $f and $fullTestName"
	fi
	i=$((i+1))
    done    
fi

endtime=$(date)
echo "endtime: $endtime"
