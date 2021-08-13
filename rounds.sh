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

    for f in $(find -name "TEST-*.xml" -not -path "*target/surefire-reports/junitreports/*"); do python $dir/python-scripts/parse_surefire_report.py $f $i $fullTestName; done >> rounds-test-results.csv

    mkdir -p ${RESULTSDIR}/isolation/$i
    mv mvn-test-$i.log ${RESULTSDIR}/isolation/$i
    for f in $(find -name "TEST-*.xml" -not -path "*target/surefire-reports/junitreports/*"); do mv $f ${RESULTSDIR}/isolation/$i; done
done

mv rounds-test-results.csv ${RESULTSDIR}/isolation
