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
mavenorder=$3
line=$(head -n 1 $projfile)

echo "================Starting experiment for input: $line"
slug=$(echo ${line} | cut -d',' -f1 | rev | cut -d'/' -f1-2 | rev)
sha=$(echo ${line} | cut -d',' -f2)
module=$(echo ${line} | cut -d',' -f3)

MVNOPTIONS="-Ddependency-check.skip=true -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip"

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"

# echo "================Cloning the project"
bash $dir/clone-project.sh "$slug" "$sha"
cd ~/$slug

echo "================Setting up test name"
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

if [[ "$modifiedslug_with_sha" == "openpojo.openpojo-9badbcc" ]]; then
    echo "Setting variables for $modifiedslug_with_sha"
    wget -nv https://files-cdn.liferay.com/mirrors/download.oracle.com/otn-pub/java/jdk/7u80-b15/jdk-7u80-linux-x64.tar.gz
    tar -zxf jdk-7u80-linux-x64.tar.gz
    dirop=$(pwd)
    old_java=$JAVA_HOME
    export JAVA_HOME=$dirop/jdk1.7.0_80/
    MVNOPTIONS="${MVNOPTIONS} -Dhttps.protocols=TLSv1.2"
fi

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
bash $dir/setup-custom-maven.sh "${RESULTSDIR}" "$dir"
cd ~/$slug

echo "================Modifying pom for runOrder"
bash $dir/pom-modify/modify-project.sh . modifyOrder=$mavenorder
#ordering="-Dsurefire.runOrder=$mavenorder" # Disabled because OBO plugin does not support setting runOrders on the command line
#echo "Ordering to run: $ordering"

if [[ "$modifiedslug_with_sha" == "openpojo.openpojo-9badbcc" ]]; then
    echo "Resetting JAVA_HOME to $old_java"
    export JAVA_HOME=$old_java
fi

#echo "================Running maven test"
bash $dir/mvn-test.sh "$slug" "$module" "$testarg" "$MVNOPTIONS" "$ordering" "$sha" "$dir"
ret=${PIPESTATUS[0]}
cp mvn-test.log ${RESULTSDIR}

# echo "================Parsing test list"
bash $dir/parse-test-list.sh "$dir" "$fullTestName" "$RESULTSDIR"

# echo "================Running rounds"
bash $dir/rounds.sh "$rounds" "$slug" "$testarg" "$MVNOPTIONS" "$RESULTSDIR" "$module" "$dir" "$fullTestName" "$ordering"

endtime=$(date)
echo "endtime: $endtime"
