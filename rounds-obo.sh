i=$1
total=$2
# f is polluter
f=$3
# fullTestName is victim
fullTestName=$4
fullClass=$5
testName=$6
slug=$7
module=$8
JMVNOPTIONS=$9
dir=${10}
RESULTSDIR=${11}
hashfile=${12}
mode=${13}

echo "Iteration $i / $total"

if [[ "$mode" == "idempotent" ]]; then
    origTestName=$(echo $f | rev | cut -d'.' -f1 | rev)
    origFullTestName="$f"
    testName="copy${origTestName}"
    fullClass=$(echo $f | rev | cut -d'.' -f2- | rev)
    fullTestName="$fullClass.$testName"
    className=$(echo $fullClass | rev | cut -d'.' -f1 | rev)
    classpath=$(find -name $className.java)
    git checkout -- $classpath
    sed -i "/public.*class /a    @org.junit.Test public void ${testName}() throws Exception {\
        ${origTestName}();\
    }" $classpath
    echo "Creating copy method: $testName"
    git diff $classpath
fi

if [[ "$f" == "$fullTestName" ]]; then
    echo "Skipping this iteration to prevent running the same test twice."
else
    echo "Pairing $f and $fullTestName"
    mhash=$(echo -n "$f-$fullTestName" | md5sum | cut -d' ' -f1);
    echo "Pair info: $f,$fullTestName,$mhash,$i"
    echo "$f,$fullTestName,$mhash,$i" >> $hashfile
    find . -name TEST-*.xml -delete
    fc="$(echo $f | rev | cut -d. -f2- | rev)"
    ft="$(echo $f | rev | cut -d. -f1 | rev)"
    if [[ "$mode" == "idempotent" ]]; then
	testarg="-Dtest=$fc#$ft,$fullClass#$testName";
    else
	testarg="-Dtest=$fc#$ft,$fullClass#$testName -DflakyTestOrder=$ft($fc),$testName($fullClass)";
    fi
    mvn test -pl $module ${testarg} ${JMVNOPTIONS} |& tee mvn-test-$i-$mhash.log

    echo "" > $i-$mhash.csv
    pf=$(find -name "TEST-${fc}.xml" | head -n 1)
    vf=$(find -name "TEST-${fullClass}.xml" | head -n 1)
    python $dir/python-scripts/parse_surefire_report.py $pf $i $f >> $i-$mhash.csv
    python $dir/python-scripts/parse_surefire_report.py $vf $i $fullTestName >> $i-$mhash.csv
    sort -u $i-$mhash.csv -o $i-$mhash.csv

    for j in $(find -name "TEST-*.xml"); do
	if [[ "$j" != "$vf" && "$j" != "$pf" ]]; then
	    python $dir/python-scripts/parse_surefire_report.py $j $i "" >> $i-$mhash.csv
	fi
    done
    cp $i-$mhash.csv ${RESULTSDIR}/pair-results

    python $dir/python-scripts/parse_obo_results.py $i-$mhash.csv $fullTestName $f  >> ${RESULTSDIR}/rounds-test-results.csv

    didfail=$(grep -v ,pass, $i-$mhash.csv)
    if [[ ! -z $didfail ]]; then
	echo "RESULT at least one test failed for: $f and $fullTestName"
	mkdir -p ${RESULTSDIR}/pairs/$i
	mv mvn-test-$i-$mhash.log ${RESULTSDIR}/pairs/$i
	for g in $(find -name "TEST*.xml"); do
	    mv $g ${RESULTSDIR}/pairs/$i
	done
	if [[ "$mode" == "idempotent" ]]; then
	    git diff $classpath > ${RESULTSDIR}/pairs/$i/patch.diff
	fi
    else
	echo "RESULT Both tests passed: $f and $fullTestName"
    fi
fi

if [[ "$mode" == "idempotent" ]]; then
    git checkout -- $classpath
fi
