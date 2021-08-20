rounds=$1
modified_slug_sha_module=$2
testarg=$3
MVNOPTIONS=$4
RESULTSDIR=$5
module=$6
dir=$7
fullTestName=$8
ordering=$9
start=${10}

echo "================Running rounds: $(date)"
pip install BeautifulSoup4
pip install lxml

for ((i=start;i<=rounds;i++)); do
    echo "Iteration: $i / $rounds : $(date)"
    find -name "TEST-*.xml" -delete
    set -x
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
    set +x

    mkdir -p ${RESULTSDIR}/isolation/$i
    mv mvn-test-$i.log ${RESULTSDIR}/isolation/$i
    for f in $(find -name "TEST-*.xml" -not -path "*target/surefire-reports/junitreports/*"); do mv $f ${RESULTSDIR}/isolation/$i; done

    if [[ "$modified_slug_sha_module" == "alibaba.fastjson-e05e9c5=." ]]; then
	# Added because alibaba-fastjson's JVM would crash during 100 rounds with run_surefire_azure.sh if dependencies were not reset.
	# Dependencies that causes the crash after ~50 runs: winglam2@mir.cs.illinois.edu:/home/winglam2/public_html/personal/dependencies_alibaba.fastjson-e05e9c5=.-bak.zip
        echo "==== Clearing dependencies for alibaba.fastjson-e05e9c5=."
        curr_dir=$(pwd)
        cd $AZ_BATCH_TASK_WORKING_DIR/dependencies
        rm -rf dependencies_${modified_slug_sha_module}
        unzip -q dependencies_${modified_slug_sha_module}.zip
        cp -r $AZ_BATCH_TASK_WORKING_DIR/custom-maven-surefire-m2/* dependencies_${modified_slug_sha_module}/
        cd ${curr_dir}
    fi
done

mv rounds-test-results.csv ${RESULTSDIR}/isolation
