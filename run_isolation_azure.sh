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

# echo "================Setting up maven-surefire"
bash setup-custom-maven.sh ${RESULTSDIR} $dir

# echo "================Cloning the project"
bash clone-project.sh $slug $sha

echo "================Setting up test name"
testarg=""
if [[ $fullTestName == "-" ]]; then
    echo "No test name given for isolation. Exiting immediately"
    date
    exit 1
else
    # if [[ "$slug" == "espertechinc/esper" ]]; then
    # 	formatTest="$(echo $fullTestName | rev | cut -d. -f2 | rev)"
    # elif [[ $fullTestName == "org.apache.hadoop.hbase.regionserver.TestSyncTimeRangeTracker" || $fullTestName == "org.apache.hadoop.hbase.snapshot.TestMobRestoreSnapshotHelper" ]]; then
    # 	formatTest="$(echo $fullTestName | rev | cut -d. -f2 | rev)"
    # else
    # 	formatTest="$(echo $fullTestName | rev | cut -d. -f2 | rev)#$(echo $fullTestName | rev | cut -d. -f1 | rev )"
    # fi
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

# echo "================Checking surefire version"
# pip install BeautifulSoup4
# pip install lxml
# for f in $(find -name pom.xml); do
#     echo "==== $f"
#     python $dir/python-scripts/parse_pom_xml.py $f
# done

# echo "================Installing the project"
bash install-project.sh $slug $MVNOPTIONS $USER $module
ret=${PIPESTATUS[0]}
mv mvn-install.log ${RESULTSDIR}
if [[ $ret != 0 ]]; then
    # mvn install does not compile - return 0
    echo "Compilation failed. Actual: $ret"
    exit 1
fi

# echo "================Running maven test"
bash mvn-test.sh $slug $module $testarg $MVNOPTIONS
ret=${PIPESTATUS[0]}
cp mvn-test.log ${RESULTSDIR}
testxml=$(find . -name TEST-*.xml | grep -E "target/surefire-reports/TEST-.*\.$class\.xml")
if [[ -z $testxml ]]; then
    # did not find
    # mvn install compiles but test is not run from mvn test - return 0
    echo "Passed compilation but cannot find an xml for the test class: $class"
    exit 1
fi

# echo "================Parsing test list"
bash parse-test-list.sh $dir $fullTestName $RESULTSDIR

# echo "================Running rounds"
bash rounds.sh $rounds $slug $testarg $MVNOPTIONS $RESULTSDIR $module $dir $fullTestName

endtime=$(date)
echo "endtime: $endtime"
