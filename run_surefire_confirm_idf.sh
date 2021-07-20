#!/bin/bash

# Takes a csv of slug,sha,module,test and flaky-list.json files for each test and runs the intended and revealed order with custom Maven surefire
# Example usage: rm -rf ~/output/; for f in $(cut -d, -f1,2,3 tuscan-84.csv | sort -u ); do s=$(echo $f | cut -d, -f1 | rev | cut -d'/' -f1,2 | rev ); sh=$(echo $f | cut -d, -f2); m=$(echo $f | cut -d, -f3); bash run_surefire_confirm_idf.sh $s $sh $m; done |& tee all-test.log
# Needs wget http://mir.cs.illinois.edu/winglam/personal/tuscan-84.csv and wget http://mir.cs.illinois.edu/winglam/personal/tuscan-84-flaky-list-json.zip

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

cd ~/

slug=$1 #$(echo ${line} | cut -d',' -f1 | rev | cut -d'/' -f1-2 | rev)
sha=$2 #$(echo ${line} | cut -d',' -f2)
input_container=$3
module=$4 #$(echo ${line} | cut -d',' -f3)
modified_module=$(echo ${module} | sed 's?\./??g' | sed 's/\//+/g')

echo "================Starting experiment for input: $slug $sha $module"

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"
modified_slug_module="${modifiedslug_with_sha}=${modified_module}"

timestamp=$(date +%s)
RESULTSDIR=~/output-${timestamp}/${modifiedslug_with_sha}
mkdir -p ${RESULTSDIR}

MVNOPTIONS="-Ddependency-check.skip=true -Dmaven.repo.local=$AZ_BATCH_TASK_WORKING_DIR/dependencies_$modified_slug_module -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip -Dcobertura.skip=true -Dfindbugs.skip=true"

# echo "================Cloning the project"
bash $dir/clone-project.sh "$slug" "$modified_slug_module" "$input_container"
ret=${PIPESTATUS[0]}
if [[ $ret != 0 ]]; then
    if [[ $ret == 2 ]]; then
        echo "$line,$modified_slug_module,cannot_clone" >> $AZ_BATCH_TASK_WORKING_DIR/$input_container/results/"$modified_slug_module-results".csv
        echo "Couldn't download the project. Actual: $ret"
        exit 1
    elif [[ $ret == 1 ]]; then
        cd ~/
        rm -rf ${slug%/*}
        wget "https://github.com/$slug/archive/$sha".zip
        ret=${PIPESTATUS[0]}
        if [[ $ret != 0 ]]; then
            echo "$line,$modified_slug_module,cannot_checkout_or_wget" >> $AZ_BATCH_TASK_WORKING_DIR/$input_container/results/"$modified_slug_module-results".csv
            echo "Compilation failed. Actual: $ret"
            exit 1
        else
            echo "git checkout failed but wget successfully downloaded the project and sha, proceeding to the rest of this script"
            mkdir -p $slug
            unzip -q $sha -d $slug
            cd $slug/*
            to_be_deleted=${PWD##*/}  
            mv * ../
            cd ../
            rm -rf $to_be_deleted  
        fi
    else
        echo "Compilation failed. Actual: $ret"
        exit 1   
    fi  
fi

cd ~/$slug

if [[ -z $module ]]; then
    echo "================ Missing module. Exiting now!"
    exit 1
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

# echo "================Running maven test"
if [[ "$slug" == "dropwizard/dropwizard" ]]; then
    # dropwizard module complains about missing dependency if one uses -pl for some modules. e.g., ./dropwizard-logging
    MVNOPTIONS="${MVNOPTIONS} -am"
elif [[ "$slug" == "fhoeben/hsac-fitnesse-fixtures" ]]; then
    MVNOPTIONS="${MVNOPTIONS} -DskipITs"
fi

echo "================Setup to parse test list"
pip install BeautifulSoup4
pip install lxml

echo "================Running intended and revealed orders for tests"

permClassFile="Tests_${modified_slug_module}"
rm -f $permClassFile
for testmethod in $(grep $slug,$sha,$module $dir/tuscan-84.csv | cut -d, -f4); do
    echo $testmethod >> $permClassFile
done

for f in $(cat $permClassFile); do
    echo "Running passing and failing for test: $f"

    shortname=$(echo $f | rev | cut -d, -f-3 | rev)

    jfile=$(find $dir/tuscan-84-flaky-list-json -name "*=${f}_*")
    python $dir/python-scripts/parse_flaky_lists_json.py $jfile
    mkdir -p ${RESULTSDIR}/$shortname/
    cp $jfile ${RESULTSDIR}/$shortname/

    pdir=$(pwd)
    intendedf="$pdir/$(find . -maxdepth 1 -name "${f}-intended-*.txt")"
    revealedf="$pdir/$(find . -maxdepth 1 -name "${f}-revealed-*.txt")"

    echo "================================================================ Starting intended runs"
    timeout 2h mvn test -Dtest=$intendedf -Dsurefire.methodRunOrder=fixed ${MVNOPTIONS} -pl $module |& tee intended.log
    mkdir -p ${RESULTSDIR}/$shortname/intended/
    mkdir -p ${RESULTSDIR}/$shortname/intended/surefire/
    mv intended.log ${RESULTSDIR}/$shortname/intended/
    mv $intendedf ${RESULTSDIR}/$shortname/intended/
    echo "" > intended-results.csv
    for j in $(find -name "TEST-*.xml"); do
	python $dir/python-scripts/parse_surefire_report.py $j -1 "" >> intended-results.csv
	mv $j ${RESULTSDIR}/$shortname/intended/surefire/
    done
    mv intended-results.csv ${RESULTSDIR}/$shortname/intended/

    echo "================================================================ Starting revealed runs"
    timeout 2h mvn test -Dtest=$revealedf -Dsurefire.methodRunOrder=fixed ${MVNOPTIONS} -pl $module |& tee revealed.log
    mkdir -p ${RESULTSDIR}/$shortname/revealed/
    mkdir -p ${RESULTSDIR}/$shortname/revealed/surefire/
    mv revealed.log ${RESULTSDIR}/$shortname/revealed/
    mv $revealedf ${RESULTSDIR}/$shortname/revealed/
    echo "" > revealed-results.csv
    for j in $(find -name "TEST-*.xml"); do
	python $dir/python-scripts/parse_surefire_report.py $j -1 "" >> revealed-results.csv
	mv $j ${RESULTSDIR}/$shortname/revealed/surefire/
    done
    mv revealed-results.csv ${RESULTSDIR}/$shortname/revealed/
done

cp $permClassFile ${RESULTSDIR}/

endtime=$(date)
echo "endtime: $endtime"
