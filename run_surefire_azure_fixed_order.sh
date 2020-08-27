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
module=$(echo ${line} | cut -d',' -f3)

echo "================Setting up maven-surefire"
cd ~/
git clone https://github.com/gmu-swe/maven-surefire.git
cd maven-surefire/
git checkout test-method-sorting
mvn install -DskipTests -Drat.skip |& tee surefire-install.log
mv surefire-install.log ${RESULTSDIR}

echo "================Setting up maven-extension"
cd $dir/archaeology/archaeology-maven-extension/
mvn install -DskipTests |& tee extension-install.log
mv extension-install.log ${RESULTSDIR}
mv target/surefire-changing-maven-extension-1.0-SNAPSHOT.jar ~/apache-maven/lib/ext/

echo "================Cloning the project"
cd ~/
MVNOPTIONS="-Ddependency-check.skip=true -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip"
git clone https://github.com/$slug $slug
cd $slug
git checkout $sha 

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

echo "================Modifying pom for runOrder"
bash $dir/pom-modify/modify-project.sh . modifyOrder

echo "================Running maven test"
if [[ "$slug" == "dropwizard/dropwizard" ]]; then
    # dropwizard module complains about missing dependency if one uses -pl for some modules. e.g., ./dropwizard-logging
    mvn test -pl $module -am ${MVNOPTIONS} -Dsurefire.runOrder=reversealphabetical |& tee mvn-test.log
elif [[ "$slug" == "fhoeben/hsac-fitnesse-fixtures" ]]; then
    mvn test -pl $module ${MVNOPTIONS} -DskipITs -Dsurefire.runOrder=reversealphabetical |& tee mvn-test.log
else
    mvn test -pl $module ${MVNOPTIONS} -Dsurefire.runOrder=reversealphabetical |& tee mvn-test.log
fi

ret=${PIPESTATUS[0]}
cp mvn-test.log ${RESULTSDIR}

echo "================Parsing test list"
pip install BeautifulSoup4
pip install lxml

echo "" > test-results.csv
for f in $(find -name "TEST*.xml"); do
    python $dir/python-scripts/parse_surefire_report.py $f 1 ""  >> test-results.csv
done
cat test-results.csv | sort -u | awk NF > ${RESULTSDIR}/test-results.csv

mkdir -p ${RESULTSDIR}/isolation

cat ${RESULTSDIR}/test-results.csv > rounds-test-results.csv
mkdir -p ${RESULTSDIR}/isolation/1
cp mvn-test.log ${RESULTSDIR}/isolation/1/mvn-test-1.log
for f in $(find -name "TEST*.xml"); do mv $f ${RESULTSDIR}/isolation/1; done

echo "================Running rounds"
set -x
for ((i=2;i<=rounds;i++)); do
    echo "Iteration: $i / $rounds"
    find -name "TEST-*.xml" -delete

    if [[ "$slug" == "dropwizard/dropwizard" ]]; then
	# dropwizard module complains about missing dependency if one uses -pl for some modules. e.g., ./dropwizard-logging
	mvn test -pl $module -am ${MVNOPTIONS} -Dsurefire.runOrder=reversealphabetical |& tee mvn-test-$i.log
    elif [[ "$slug" == "fhoeben/hsac-fitnesse-fixtures" ]]; then
	mvn test -pl $module ${MVNOPTIONS} -DskipITs -Dsurefire.runOrder=reversealphabetical |& tee mvn-test-$i.log
    else
	mvn test -pl $module ${MVNOPTIONS} -Dsurefire.runOrder=reversealphabetical |& tee mvn-test-$i.log
    fi
    
    for f in $(find -name "TEST*.xml"); do python $dir/python-scripts/parse_surefire_report.py $f $i ""; done >> rounds-test-results.csv

    mkdir -p ${RESULTSDIR}/isolation/$i
    mv mvn-test-$i.log ${RESULTSDIR}/isolation/$i
    for f in $(find -name "TEST*.xml"); do mv $f ${RESULTSDIR}/isolation/$i; done
done

mv rounds-test-results.csv ${RESULTSDIR}/isolation

endtime=$(date)
echo "endtime: $endtime"
