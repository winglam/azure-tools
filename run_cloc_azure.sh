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
slugFull=$(echo ${line} | cut -d',' -f1)
slug=$(echo ${line} | cut -d',' -f1 | rev | cut -d'/' -f1-2 | rev)
sha=$(echo ${line} | cut -d',' -f2)

echo "================Installing the project"
MVNOPTIONS="-fn -Ddependency-check.skip=true -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip"
git clone https://github.com/$slug $slug
cd $slug
git checkout $sha 

if [[ "$slug" == "apache/incubator-dubbo" ]]; then
    sudo chown -R $USER .
    mvn clean install -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$slug" == "openpojo/openpojo" ]]; then
    wget https://files-cdn.liferay.com/mirrors/download.oracle.com/otn-pub/java/jdk/7u80-b15/jdk-7u80-linux-x64.tar.gz
    tar -zxf jdk-7u80-linux-x64.tar.gz
    dir=$(pwd)
    export JAVA_HOME=$dir/jdk1.7.0_80/
    MVNOPTIONS="${MVNOPTIONS} -Dhttps.protocols=TLSv1.2"
    mvn clean install -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
else
    mvn clean install -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
fi

ret=${PIPESTATUS[0]}
mv mvn-install.log ${RESULTSDIR}
if [[ $ret != 0 ]]; then
    # mvn install does not compile - return 0
    echo "Compilation failed. Actual: $ret"
    exit 1
fi

# Timeout for each module's test is 3hr
mvn test ${MVNOPTIONS} -Dsurefire.timeout=10800 -X |& tee mvn-test-all.log

ret=${PIPESTATUS[0]}
mv mvn-test-all.log ${RESULTSDIR}

echo "================Parsing test list"
pip install BeautifulSoup4
pip install lxml

wget http://mir.cs.illinois.edu/winglam/personal/parse_surefire_report-a281abbecbac34c5de4d68e87d921ddd8f49c8c6.py -O ${RESULTSDIR}/parse_surefire_report.py
echo "" > all-test-results.csv
for f in $(find -name "TEST*.xml"); do
    python ${RESULTSDIR}/parse_surefire_report.py $f -1  >> all-test-results.csv
done
cat all-test-results.csv | sort -u | awk NF > ${RESULTSDIR}/all-test-results.csv


rm -rf ${RESULTSDIR}/summary.csv
rm -rf ${RESULTSDIR}/loc.csv
for g in $(find -name pom.xml); do
    moduledir=$(echo $g | rev | cut -d'/' -f2- | rev)
    echo "================Checking module: $moduledir"

    cd $moduledir/
    mkdir -p ${RESULTSDIR}/$moduledir
    rm -rf module-test-results.csv
    for f in $(find -name "TEST*.xml"); do
	python ${RESULTSDIR}/parse_surefire_report.py $f -1  >> module-test-results.csv
    done
    cat module-test-results.csv | sort -u | awk NF > ${RESULTSDIR}/$moduledir/module-test-results.csv

    cloc . --csv --quiet | grep -v -e '^$' | grep -v files,language,blank,comment,code | grep -v Counting: | sed -e "s|^|all,$moduledir,|" >> ${RESULTSDIR}/loc.csv
    cloc . --csv --quiet --match-d='/src/main/java/' | grep -v -e '^$' | grep -v files,language,blank,comment,code | grep -v Counting: | sed -e "s|^|cut,$moduledir,|" >> ${RESULTSDIR}/loc.csv
    cloc . --csv --quiet --match-d='/src/test/java/' | grep -v -e '^$' | grep -v files,language,blank,comment,code | grep -v Counting: | sed -e "s|^|test,$moduledir,|" >> ${RESULTSDIR}/loc.csv

    allCode=$(grep "^all,\\$moduledir," ${RESULTSDIR}/loc.csv | grep ,Java, | cut -d, -f7 | sort -u)
    cutCode=$(grep "^cut,\\$moduledir," ${RESULTSDIR}/loc.csv | grep ,Java, | cut -d, -f7 | sort -u)
    testCode=$(grep "^test,\\$moduledir," ${RESULTSDIR}/loc.csv | grep ,Java, | cut -d, -f7 | sort -u)
    testCount=$(wc -l ${RESULTSDIR}/$moduledir/module-test-results.csv | cut -d' ' -f1)
    echo $slugFull,$sha,$moduledir,$allCode,$cutCode,$testCode,$testCount >> ${RESULTSDIR}/summary.csv
    
    cd -
done

hasall=$(grep all,., ${RESULTSDIR}/loc.csv)
if [[ -z $hasall ]]; then
    cloc . --csv --quiet | grep -v -e '^$' | grep -v files,language,blank,comment,code | grep -v Counting: | sed -e "s|^|all,.,|" >> ${RESULTSDIR}/loc.csv
    cloc . --csv --quiet --match-d='/src/main/java/' | grep -v -e '^$' | grep -v files,language,blank,comment,code | grep -v Counting: | sed -e "s|^|cut,.,|" >> ${RESULTSDIR}/loc.csv
    cloc . --csv --quiet --match-d='/src/test/java/' | grep -v -e '^$' | grep -v files,language,blank,comment,code | grep -v Counting: | sed -e "s|^|test,.,|" >> ${RESULTSDIR}/loc.csv
fi

# Save all Test XMLs
mkdir -p ${RESULTSDIR}/xmls/
for f in $(find -name "TEST*.xml"); do mv $f ${RESULTSDIR}/xmls/; done


cd ${RESULTSDIR}/

allCode=$(grep "^all,\.," loc.csv | grep ,Java, | cut -d, -f7 | sort -u)
cutCode=$(grep "^cut,\.," loc.csv | grep ,Java, | cut -d, -f7 | sort -u)
testCode=$(grep "^test,\.," loc.csv | grep ,Java, | cut -d, -f7 | sort -u)
testCount=$(wc -l all-test-results.csv | cut -d' ' -f1)
echo $slugFull,$sha,.,$allCode,$cutCode,$testCode,$testCount >> summary.csv

sort -u summary.csv > t
rm summary.csv
mv t summary.csv
