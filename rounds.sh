rounds=$1
slug=$2
testarg=$3
MVNOPTIONS=$4
RESULTSDIR=$5
module=$6
dir=$7
fullTestName=$8
ordering=$9

echo "================Running rounds"
set -x
for ((i=2;i<=rounds;i++)); do
    echo "Iteration: $i / $rounds"
    find -name "TEST-*.xml" -delete

    if [[ "$slug" == "dropwizard/dropwizard" ]]; then
	# dropwizard module complains about missing dependency if one uses -pl for some modules. e.g., ./dropwizard-logging
	mvn test -pl $module -am ${testarg} ${MVNOPTIONS} $ordering |& tee mvn-test-$i.log
    elif [[ "$slug" == "fhoeben/hsac-fitnesse-fixtures" ]]; then
	mvn test -pl $module ${testarg} ${MVNOPTIONS} $ordering -DskipITs |& tee mvn-test-$i.log
    else
	mvn test -pl $module ${testarg} ${MVNOPTIONS} $ordering |& tee mvn-test-$i.log
    fi

    for f in $(find -name "TEST*.xml"); do python $dir/python-scripts/parse_surefire_report.py $f $i $fullTestName; done >> rounds-test-results.csv

    mkdir -p ${RESULTSDIR}/isolation/$i
    mv mvn-test-$i.log ${RESULTSDIR}/isolation/$i
    for f in $(find -name "TEST*.xml"); do mv $f ${RESULTSDIR}/isolation/$i; done
done

mv rounds-test-results.csv ${RESULTSDIR}/isolation
