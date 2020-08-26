#!/bin/bash

echo "epoch: 1590617255"

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
    if [[ "$fullTestName" == "retrofit2.adapter.rxjava.CancelDisposeTest.cancelDoesNotDispose" ]]; then
	module="./retrofit-adapters/rxjava"
    elif [[ "$fullTestName" == "retrofit2.adapter.rxjava.CompletableThrowingTest.bodyThrowingInOnErrorDeliveredToPlugin" ]]; then
	module="./retrofit-adapters/rxjava"
    elif [[ "$fullTestName" == "retrofit2.adapter.rxjava.CompletableThrowingTest.throwingInOnCompleteDeliveredToPlugin" ]]; then
	module="./retrofit-adapters/rxjava"
    elif [[ "$fullTestName" == "retrofit2.adapter.rxjava.ObservableThrowingTest.responseThrowingInOnCompleteDeliveredToPlugin" ]]; then
	module="./retrofit-adapters/rxjava"
    elif [[ "$fullTestName" == "retrofit2.adapter.rxjava.SingleThrowingTest.bodyThrowingInOnSuccessDeliveredToPlugin" ]]; then
	module="./retrofit-adapters/rxjava"
    elif [[ "$fullTestName" == "retrofit2.adapter.rxjava.SingleThrowingTest.responseThrowingInOnSuccessDeliveredToPlugin" ]]; then
	module="./retrofit-adapters/rxjava"
    elif [[ "$fullTestName" == "net.redpipe.templating.freemarker.ApiTest.checkMail" ]]; then
	module="./redpipe-templating-freemarker"
    elif [[ "$fullTestName" == "net.redpipe.templating.freemarker.ApiTest.checkTemplateNegociationText" ]]; then
	module="./redpipe-templating-freemarker"
    elif [[ "$fullTestName" == "net.redpipe.templating.freemarker.ApiTest.checkTemplateNegociationSingleHtml" ]]; then
	module="./redpipe-templating-freemarker"
    else
	while [[ "$module" != "." && "$module" != "" ]]; do
	    module=$(echo $module | rev | cut -d'/' -f2- | rev)
	    echo "Checking for pom at: $module"
	    if [[ -f $module/pom.xml ]]; then
		break;
	    fi
	done
    fi
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
elif [[ "$slug" == "zalando/riptide" ]]; then
    rm -rf pom.xml
    wget -O pom.xml http://mir.cs.illinois.edu/winglam/personal/zalando-pom.xml
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


echo "================Modifying pom for runOrder"
wget http://mir.cs.illinois.edu/winglam/personal/pom-modify.zip
unzip -q pom-modify.zip
bash pom-modify/modify-project.sh . modifyOrder

mvn test -pl $module ${MVNOPTIONS} -Dsurefire.runOrder=reversealphabetical -X |& tee mvn-test.log

ret=${PIPESTATUS[0]}
mv mvn-test.log ${RESULTSDIR}

echo "================Parsing test list"
pip install BeautifulSoup4
pip install lxml

wget http://mir.cs.illinois.edu/winglam/personal/parse_surefire_report-a281abbecbac34c5de4d68e87d921ddd8f49c8c6.py -O parse_surefire_report.py
echo "" > test-results.csv
for f in $(find -name "TEST*.xml"); do
    python parse_surefire_report.py $f -1  >> test-results.csv
done
cat test-results.csv | sort -u | awk NF > ${RESULTSDIR}/test-results.csv

fullClass="$(echo $fullTestName | rev | cut -d. -f2- | rev)"
testName="$(echo $fullTestName | rev | cut -d. -f1 | rev )"

set -x

mkdir -p ${RESULTSDIR}/isolation
echo "" > rounds-test-results.csv
for ((i=1;i<=rounds;i++)); do
    echo "Iteration: $i / $rounds"
    find -name "TEST-*.xml" -delete

    mvn test -pl $module ${MVNOPTIONS} -Dsurefire.runOrder=reversealphabetical |& tee mvn-test-$i.log
    for f in $(find -name "TEST*.xml"); do python parse_surefire_report.py $f $i; done >> rounds-test-results.csv

    mkdir -p ${RESULTSDIR}/isolation/$i
    mv mvn-test-$i.log ${RESULTSDIR}/isolation/$i
    for f in $(find -name "TEST*.xml"); do mv $f ${RESULTSDIR}/isolation/$i; done
done

mv rounds-test-results.csv ${RESULTSDIR}/isolation
