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
line=$(head -n 1 $projfile)

echo "================Starting experiment for input: $line"
slug=$(echo ${line} | cut -d',' -f1 | rev | cut -d'/' -f1-2 | rev)
sha=$(echo ${line} | cut -d',' -f2)

fullTestName="running.idempotent"
module=$(echo ${line} | cut -d',' -f3)
modified_module=$(echo ${module} | sed 's?\./??g' | sed 's/\//+/g')

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"
modified_slug_module="${modifiedslug_with_sha}=${modified_module}"

MVNOPTIONS="-Ddependency-check.skip=true -Dmaven.repo.local=$AZ_BATCH_TASK_WORKING_DIR/dependencies/dependencies_${modified_slug_module} -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip -Dcobertura.skip=true -Dfindbugs.skip=true"

# echo "================Cloning the project"
bash $dir/clone-project.sh "$slug" "$modified_slug_module" "$input_container"
ret=${PIPESTATUS[0]}
if [[ $ret != 0 ]]; then
    if [[ $ret == 2 ]]; then
        echo "Couldn't download the project. Actual: $ret"
        exit 1
    elif [[ $ret == 1 ]]; then
        cd ~/
        rm -rf ${slug%/*}
        wget "https://github.com/$slug/archive/$sha".zip
        ret=${PIPESTATUS[0]}
        if [[ $ret != 0 ]]; then
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

echo "================Setting up test name: $(date)"
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

echo "================Setup to parse test list: $(date)"
pip install BeautifulSoup4
pip install lxml

if [[ "$slug" == "dropwizard/dropwizard" ]]; then
    # dropwizard module complains about missing dependency if one uses -pl for some modules. e.g., ./dropwizard-logging
    MVNOPTIONS="${MVNOPTIONS} -am"
elif [[ "$slug" == "fhoeben/hsac-fitnesse-fixtures" ]]; then
    MVNOPTIONS="${MVNOPTIONS} -DskipITs"
fi

echo "================Starting OBO: $(date)"
fullClass="$(echo $fullTestName | rev | cut -d. -f2- | rev)"
testName="$(echo $fullTestName | rev | cut -d. -f1 | rev )"
hashfile="${RESULTSDIR}/p-v-hash.csv"
echo "polluter,victim,hash,round_num" > $hashfile
mkdir -p ${RESULTSDIR}/pair-results

tl="$dir/module-summarylistgen-idempotent/${modified_slug_module}_output.csv"
cp $tl ${RESULTSDIR}/
total=$(cat $tl | wc -l)
i=1
for f in $(cat $tl ); do
    echo "==== Iteration $i / $total : $f : $(date)"

    origFullTestName="$f"
    fullClass=$(echo $f | rev | cut -d'.' -f2- | rev)
    className=$(echo $fullClass | rev | cut -d'.' -f1 | rev)
    ft="$(echo $f | rev | cut -d'.' -f1 | rev)"
    count=$(find $module -name $className.java | wc -l)
    if [[ $count -eq 0 ]]; then
	echo "================ Error: no test file found for $className in $module"
	exit 1
    elif [[ $count -ne 1 ]]; then
	echo "================ moduleWarning: multiple test files found for $className in $module"
	find $module -name $className.java
	classpath=$(find $module -name $className.java | head -1)
    else
	classpath=$(find $module -name $className.java)
    fi
    echo "==== classpath: $classpath"
    git checkout -- $classpath

    mhash=$(echo -n "$f" | md5sum | cut -d' ' -f1);
    echo "$f,$mhash,$i" >> $hashfile
    echo "==== Pair info: $f,$mhash,$i"
    testarg="-Dtest=$fullClass#$ft";
    find . -name TEST-*.xml -delete
    mvn test -pl $module ${testarg} ${MVNOPTIONS} |& tee mvn-test-$i-$mhash.log

    echo "" > $i-$mhash.csv
    pf=$(find -name "TEST-${fullClass}.xml" | head -n 1)
    python $dir/python-scripts/parse_surefire_report-NI-tests.py $pf $i $f >> $i-$mhash.csv

    TMPFILE=`mktemp /tmp/add_rule.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`
    awk '/public.*class / && !x {print;print "@org.junit.Rule public org.junit.rules.TestRule runtwice = new org.junit.rules.TestRule() {@Override public org.junit.runners.model.Statement apply(final org.junit.runners.model.Statement base, org.junit.runner.Description description) {return new org.junit.runners.model.Statement() {@Override public void evaluate() throws Throwable {base.evaluate();base.evaluate();}};}};"; x=1; next;} 1' $classpath > ${TMPFILE}
    # awk '/public.*class / && !x {print;print "@org.junit.ClassRule public static org.junit.rules.TestRule runtwice = new org.junit.rules.TestRule() {@Override public org.junit.runners.model.Statement apply(final org.junit.runners.model.Statement base, org.junit.runner.Description description) {return new org.junit.runners.model.Statement() {@Override public void evaluate() throws Throwable {base.evaluate();base.evaluate();}};}};"; x=1; next;} 1' $classpath > ${TMPFILE}
    cp ${TMPFILE} ${classpath}
    echo "==== Adding rule:"
    git diff $classpath

    find . -name TEST-*.xml -delete
    mvn test -pl $module ${testarg} ${MVNOPTIONS} |& tee mvn-test-$i-$mhash-2nd.log
    python $dir/python-scripts/parse_surefire_report-NI-tests.py $pf $i "${f}=DUPLICATE" >> $i-$mhash.csv
    sort -u $i-$mhash.csv -o $i-$mhash.csv

    for j in $(find -name "TEST-*.xml"); do
	if [[ "$j" != "$pf" ]]; then
	    python $dir/python-scripts/parse_surefire_report-NI-tests.py $j $i "" >> $i-$mhash.csv
	fi
    done
    cp $i-$mhash.csv ${RESULTSDIR}/pair-results

    python $dir/python-scripts/parse_obo_results.py $i-$mhash.csv "${f}=DUPLICATE" $f > /tmp/obo_results.xxxxxxxxxxxx
    cat /tmp/obo_results.xxxxxxxxxxxx >> ${RESULTSDIR}/rounds-test-results.csv

    didfail=$(egrep ",PP_VF,|,PF_VP,|,MP,|,MV,|,MVP," /tmp/obo_results.xxxxxxxxxxxx)
    if [[ ! -z $didfail ]]; then
	echo "RESULT at least one ,PP_VF,|,PF_VP,|,MP,|,MV,|,MVP, test: $f"
	mkdir -p ${RESULTSDIR}/pairs/$i
	mv mvn-test-$i-$mhash.log ${RESULTSDIR}/pairs/$i
	mv mvn-test-$i-$mhash-2nd.log ${RESULTSDIR}/pairs/$i
	for g in $(find -name "TEST*.xml"); do
	    mv $g ${RESULTSDIR}/pairs/$i
	done
	git diff $classpath > ${RESULTSDIR}/pairs/$i/patch.diff
    else
	echo "RESULT tests either all passed or all failed: $f"
    fi

    git checkout -- $classpath    
    i=$((i+1))
done    

endtime=$(date)
echo "endtime: $endtime"
