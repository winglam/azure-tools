dir=$1
fullTestName=$2
RESULTSDIR=$3

echo "================Parsing test list"
pip install BeautifulSoup4
pip install lxml

rm -f test-results.csv

for g in $(egrep "^Running|^\[INFO\] Running " mvn-test.log | rev | cut -d' ' -f1 | rev); do
    f=$(find -name "TEST-${g}.xml" -not -path "*target/surefire-reports/junitreports/*");
    fcount=$(echo "$f" | wc -l);
    if [[ "$fcount" != "1" ]]; then
	echo "================ ERROR finding TEST-${g}.xml: $fcount:"
	echo "$f";
	continue;
    fi

    python $dir/python-scripts/parse_surefire_report.py $f 1 $fullTestName  >> test-results.csv;
done
mv test-results.csv ${RESULTSDIR}/test-results.csv

mkdir -p ${RESULTSDIR}/isolation

cat ${RESULTSDIR}/test-results.csv > rounds-test-results.csv
mkdir -p ${RESULTSDIR}/isolation/1
cp mvn-test.log ${RESULTSDIR}/isolation/1/mvn-test-1.log
for f in $(find -name "TEST*.xml" -not -path "*target/surefire-reports/junitreports/*"); do mv $f ${RESULTSDIR}/isolation/1; done
