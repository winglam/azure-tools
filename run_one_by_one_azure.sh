#!/bin/bash

echo "epoch: 1589140675"

if [[ $1 == "" ]]; then
    echo "arg1 - Path to CSV file with project,sha,test"
    exit
fi

RESULTSDIR=~/output/
mkdir -p ${RESULTSDIR}

echo "================Setting up maven-surefire"
cd ~/
git clone https://github.com/gmu-swe/maven-surefire.git
cd maven-surefire/
git checkout test-method-sorting
mvn install -DskipTests -Drat.skip |& tee surefire-install.log
mv surefire-install.log ${RESULTSDIR}

echo "================Setting up maven-extension"
cd ~/
wget http://mir.cs.illinois.edu/winglam/personal/archaeology-maven-extension-72a34bdd44120728757d8980e4c7915c8c4a5dae.zip
unzip -q archaeology-maven-extension-72a34bdd44120728757d8980e4c7915c8c4a5dae.zip
cd archaeology-maven-extension/
mvn install -DskipTests |& tee extension-install.log
mv extension-install.log ${RESULTSDIR}
mv target/surefire-changing-maven-extension-1.0-SNAPSHOT.jar ~/apache-maven/lib/ext/

cd ~/
projfile=$1
line=$(head -n 1 $projfile)
echo "================Starting experiment for input: $line"
slug=$(echo ${line} | cut -d',' -f1 | rev | cut -d'/' -f1-2 | rev)
sha=$(echo ${line} | cut -d',' -f2)
fullTestName=$(echo ${line} | cut -d',' -f3)
module=$(echo ${line} | cut -d',' -f4)

echo "================Installing the project"
MVNOPTIONS="-Ddependency-check.skip=true -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip"
git clone https://github.com/$slug $slug
cd $slug
git checkout $sha 

if [[ $fullTestName == "org.apache.hadoop.hbase.regionserver.TestSyncTimeRangeTracker" || $fullTestName == "org.apache.hadoop.hbase.snapshot.TestMobRestoreSnapshotHelper" ]]; then
    formatTest="$(echo $fullTestName | rev | cut -d. -f2 | rev)"
    class="$(echo $fullTestName | rev | cut -d. -f2 | rev)"
else
    formatTest="$(echo $fullTestName | rev | cut -d. -f2 | rev)#$(echo $fullTestName | rev | cut -d. -f1 | rev )"
    class="$(echo $fullTestName | rev | cut -d. -f2 | rev)"
fi

echo "formatTest: $formatTest"
echo "class: $class"

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

if [[ "$slug" == "apache/incubator-dubbo" ]]; then
    sudo chown -R $USER .
    mvn clean install -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$slug" == "openpojo/openpojo" ]]; then
    wget https://files-cdn.liferay.com/mirrors/download.oracle.com/otn-pub/java/jdk/7u80-b15/jdk-7u80-linux-x64.tar.gz
    tar -zxf jdk-7u80-linux-x64.tar.gz
    dir=$(pwd)
    export JAVA_HOME=$dir/jdk1.7.0_80/
    MVNOPTIONS="${MVNOPTIONS} -Dhttps.protocols=TLSv1.2"
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
else
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
fi

ret=${PIPESTATUS[0]}
mv mvn-install.log ${RESULTSDIR}
if [[ $ret != 0 ]]; then
    # mvn install does not compile - return 0
    echo "Compilation failed. Actual: $ret"
    exit 1
fi

mvn test -pl $module ${MVNOPTIONS} |& tee mvn-test.log

ret=${PIPESTATUS[0]}
mv mvn-test.log ${RESULTSDIR}

testxml=$(find . -name TEST-*.xml | grep -E "target/surefire-reports/TEST-.*\.$class\.xml")
if [[ -z $testxml ]]; then
    # did not find
    # mvn install compiles but test is not run from mvn test - return 0
    echo "Passed compilation but cannot find an xml for the test class: $class"
    exit 1
fi

echo "================Parsing test list"
pip install BeautifulSoup4
pip install lxml

wget http://mir.cs.illinois.edu/winglam/personal/parse_surefire_report-a281abbecbac34c5de4d68e87d921ddd8f49c8c6.py -O parse_surefire_report.py
echo "" > test-results.csv
for f in $(find -name "TEST*.xml"); do
    python parse_surefire_report.py $f -1  >> test-results.csv
done
cat test-results.csv | sort -u | awk NF > ${RESULTSDIR}/test-results.csv

oldclass="$(echo $fullTestName | rev | cut -d. -f2 | rev)"
oldtest="$(echo $fullTestName | rev | cut -d. -f1 | rev )"
oldtestcount=$(grep "$oldclass.$oldtest," test-results.csv | wc -l)
if [[ "$oldtestcount" != "1" ]]; then
    echo "exit: 105 Multiple test names found. Unsure which one to use:"
    grep "$oldclass.$oldtest," test-results.csv
    exit 105
fi
    
didpass=$(grep "$oldclass.$oldtest," test-results.csv | grep ,pass,)
if [[ -z $didpass ]]; then
    echo "exit: 1 Test failed in mvn test. Result:"
    grep "$oldclass.$oldtest," test-results.csv
    exit 1
else
    echo "oldFullTestName: $fullTestName"
    echo "mvn test result: pass"
    fullTestName=$(grep "$oldclass.$oldtest," test-results.csv | cut -d, -f1)
    echo "newFullTestName: $fullTestName"
fi

JMVNOPTIONS="${MVNOPTIONS} -Dsurefire.methodRunOrder=flakyfinding -Djava.awt.headless=true -Dmaven.main.skip -DtrimStackTrace=false -Dmaven.test.failure.ignore=true"

# -Dtest=com.opensymphony.xwork2.TestNGXWorkTestCaseTest$RunTest#testRun,org.apache.struts2.portlet.dispatcher.Jsr286DispatcherTest#testProcessAction_ok
# -DflakyTestOrder='testRun(com.opensymphony.xwork2.TestNGXWorkTestCaseTest$RunTest),testProcessAction_ok(org.apache.struts2.portlet.dispatcher.Jsr286DispatcherTest)'
fullClass="$(echo $fullTestName | rev | cut -d. -f2- | rev)"
testName="$(echo $fullTestName | rev | cut -d. -f1 | rev )"

set -x

total=$(cut -d, -f1 test-results.csv | sort -u | awk NF | wc -l)
i=1
mkdir -p ${RESULTSDIR}/pair-results
for f in $(cut -d, -f1 test-results.csv | sort -u | awk NF); do
    echo "Iteration $i / $total"
    echo "Pairing $f and $fullTestName"
    find . -name TEST-*.xml -delete
    # does this work with just test and class names?
    fc="$(echo $f | rev | cut -d. -f2- | rev)"
    ft="$(echo $f | rev | cut -d. -f1 | rev)"
    order="-Dtest=$fc#$ft,$fullClass#$testName -DflakyTestOrder=$ft($fc),$testName($fullClass)";
    mvn test -pl $module ${order} ${JMVNOPTIONS} |& tee mvn-test-$i-$f-$fullTestName.log

    ret=${PIPESTATUS[0]}

    echo "" > $i-$f-$fullTestName.csv
    for j in $(find -name "TEST*.xml"); do
	python parse_surefire_report.py $j $i >> $i-$f-$fullTestName.csv
    done
    cp $i-$f-$fullTestName.csv ${RESULTSDIR}/pair-results

    didfail=$(grep -v ,pass, $i-$f-$fullTestName.csv)
    if [[ ! -z $didfail ]]; then
	echo "RESULT at least one test failed for: $f and $fullTestName"
	mkdir -p ~/output/pairs/$i
	mv mvn-test-$i-$f-$fullTestName.log ~/output/pairs/$i
	for g in $(find -name "TEST*.xml"); do
	    mv $g ~/output/pairs/$i
	done
    else
	echo "RESULT Both tests passed: $f and $fullTestName"
    fi
    i=$((i+1))
done
