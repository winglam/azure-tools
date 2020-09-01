i=$1
total=$2
f=$3
fullTestName=$4
fullClass=$5
testName=$6
slug=$7
module=$8
JMVNOPTIONS=$9
dir=$10
RESULTSDIR=$11


echo "Iteration $i / $total"
if [[ "$f" == "$fullTestName" ]]; then
    echo "Skipping this iteration to prevent running the same test twice."
else
    echo "Pairing $f and $fullTestName"
    find . -name TEST-*.xml -delete
    fc="$(echo $f | rev | cut -d. -f2- | rev)"
    ft="$(echo $f | rev | cut -d. -f1 | rev)"
    testarg="-Dtest=$fc#$ft,$fullClass#$testName -DflakyTestOrder=$ft($fc),$testName($fullClass)";
    if [[ "$slug" == "dropwizard/dropwizard" ]]; then
	# dropwizard module complains about missing dependency if one uses -pl for some modules. e.g., ./dropwizard-logging
	mvn test -pl $module -am ${testarg} ${JMVNOPTIONS} |& tee mvn-test-$i-$f-$fullTestName.log
    elif [[ "$slug" == "fhoeben/hsac-fitnesse-fixtures" ]]; then
	mvn test -pl $module ${testarg} ${JMVNOPTIONS} -DskipITs |& tee mvn-test-$i-$f-$fullTestName.log
    else
	mvn test -pl $module ${testarg} ${JMVNOPTIONS} |& tee mvn-test-$i-$f-$fullTestName.log
    fi

    echo "" > $i-$f-$fullTestName.csv
    for j in $(find -name "TEST*.xml"); do
	python $dir/python-scripts/parse_surefire_report.py $j $i "" >> $i-$f-$fullTestName.csv
    done
    cp $i-$f-$fullTestName.csv ${RESULTSDIR}/pair-results

    python $dir/python-scripts/parse_obo_results.py $i-$f-$fullTestName.csv $fullTestName $f  >> ${RESULTSDIR}/rounds-test-results.csv

    didfail=$(grep -v ,pass, $i-$f-$fullTestName.csv)
    if [[ ! -z $didfail ]]; then
	echo "RESULT at least one test failed for: $f and $fullTestName"
	mkdir -p ${RESULTSDIR}/pairs/$i
	mv mvn-test-$i-$f-$fullTestName.log ${RESULTSDIR}/pairs/$i
	for g in $(find -name "TEST*.xml"); do
	    mv $g ${RESULTSDIR}/pairs/$i
	done
    else
	echo "RESULT Both tests passed: $f and $fullTestName"
    fi
fi
