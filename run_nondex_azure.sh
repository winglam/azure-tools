#!/bin/bash

echo "epoch: 1590346682"

if [[ $1 == "" ]]; then
    echo "arg1 - Path to CSV file with project,sha,test"
    exit
fi

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
seed=$(echo ${line} | cut -d',' -f5)

echo "================Cloning the project"
MVNOPTIONS="-Ddependency-check.skip=true -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip"
git clone https://github.com/$slug $slug
cd $slug
git checkout $sha 


echo "================Setting up NonDex"
wget http://mir.cs.illinois.edu/winglam/personal/nondex-files.tar.gz
tar -xzvf nondex-files.tar.gz

chmod 755 -R nondex-files/
echo "Modifying project pom"
bash nondex-files/modify-project.sh .

echo "================Setting up test name"
testarg=""
if [[ "$fullTestName" != "" ]]; then
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
else
    echo "No test name given. Running on the entire project."
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

echo "================Installing the project"
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

echo "================Running maven test"
if [[ "$slug" == "dropwizard/dropwizard" ]]; then
    # dropwizard module complains about missing dependency if one uses -pl for some modules. e.g., ./dropwizard-logging
    mvn test ${testarg} ${MVNOPTIONS} |& tee mvn-test.log
else
    mvn test -pl $module ${testarg} ${MVNOPTIONS} |& tee mvn-test.log
fi

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

wget http://mir.cs.illinois.edu/winglam/personal/parse_surefire_report-60449f52.py -O parse_surefire_report.py
echo "" > test-results.csv
for f in $(find -name "TEST*.xml"); do
    python parse_surefire_report.py $f -1 $fullTestName  >> test-results.csv
done
cat test-results.csv | sort -u | awk NF > ${RESULTSDIR}/test-results.csv

echo "================Running NonDex"
if [[ "$slug" == "dropwizard/dropwizard" ]]; then
    # dropwizard module complains about missing dependency if one uses -pl for some modules. e.g., ./dropwizard-logging
    mvn ${testarg} nondex:nondex ${MVNOPTIONS} -DnondexMode=ONE -DnondexRuns=$rounds |& tee new_detect_log
else
    mvn ${testarg} nondex:nondex ${MVNOPTIONS} -DnondexMode=ONE -DnondexRuns=$rounds -pl $module |& tee new_detect_log
fi

awk "/Test results can be found/{t=0} {if(t)print} /Across all seeds/{t=1}" new_detect_log > ${RESULTSDIR}/nod-tests.txt
mv new_detect_log ${RESULTSDIR}

modulekey() {
    projroot=$1
    moduledir=$2

    # In case it is not a subdirectory, handle it so does not use the .
    relpath=$(realpath $(dirname ${moduledir}) --relative-to ${projroot})
    if [[ ${relpath} == '.' ]]; then
        basename ${projroot}
        return
    fi

    # Otherwise convert into expected format
    echo $(basename ${projroot})-$(realpath $(dirname ${moduledir}) --relative-to ${projroot} | sed 's;/;-;g')
}

mkdir -p ${RESULTSDIR}/nondex
for d in $(find $(pwd) -name ".nondex"); do
    cp -r ${d} ${RESULTSDIR}/nondex/$(modulekey $(pwd) ${d})
done
