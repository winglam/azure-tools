rounds=$1
slug=$2
testarg=$3
MVNOPTIONS=$4
RESULTSDIR=$5
module=$6
dir=$7
fullTestName=$8
ordering=$9
start=${10}

echo "================Running rounds"
pip install BeautifulSoup4
pip install lxml

set -x
for ((i=start;i<=rounds;i++)); do
    echo "Iteration: $i / $rounds"
    find -name "TEST-*.xml" -delete

    mvn test -pl $module ${testarg} ${MVNOPTIONS} $ordering |& tee mvn-test-$i.log

    for g in $(egrep "^Running|^\[INFO\] Running " mvn-test-$i.log | rev | cut -d' ' -f1 | rev); do
	f=$(find -name "TEST-${g}.xml" -not -path "*target/surefire-reports/junitreports/*");
	fcount=$(echo "$f" | wc -l);
	if [[ "$fcount" != "1" ]]; then
	    echo "================ ERROR finding TEST-${g}.xml: $fcount:"
	    echo "$f";
	    continue;
	fi

	python $dir/python-scripts/parse_surefire_report.py $f $i $fullTestName >> rounds-test-results.csv;
    done

    mkdir -p ${RESULTSDIR}/isolation/$i
    mv mvn-test-$i.log ${RESULTSDIR}/isolation/$i
    for f in $(find -name "TEST-*.xml" -not -path "*target/surefire-reports/junitreports/*"); do mv $f ${RESULTSDIR}/isolation/$i; done
done

mv rounds-test-results.csv ${RESULTSDIR}/isolation
