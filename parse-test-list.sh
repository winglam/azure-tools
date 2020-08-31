dir=$1
fullTestName=$2
RESULTSDIR=$3

echo "================Parsing test list"
pip install BeautifulSoup4
pip install lxml

echo "" > test-results.csv
for f in $(find -name "TEST*.xml" -not -path "*target/surefire-reports/junitreports/*"); do
    python $dir/python-scripts/parse_surefire_report.py $f 1 $fullTestName  >> test-results.csv
done
cat test-results.csv | sort -u | awk NF > ${RESULTSDIR}/test-results.csv

mkdir -p ${RESULTSDIR}/isolation

cat ${RESULTSDIR}/test-results.csv > rounds-test-results.csv
mkdir -p ${RESULTSDIR}/isolation/1
cp mvn-test.log ${RESULTSDIR}/isolation/1/mvn-test-1.log
for f in $(find -name "TEST*.xml" -not -path "*target/surefire-reports/junitreports/*"); do mv $f ${RESULTSDIR}/isolation/1; done
