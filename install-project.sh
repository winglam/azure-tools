slug=$1
MVNOPTIONS="$2 -Dmaven.repo.local=$AZ_BATCH_TASK_WORKING_DIR/input/dependencies"
USER=$3
module=$4
sha=$5
dir=$6
fullTestName=$7
RESULTSDIR=$8
projectname=${slug%/*}

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"
modified_module=$(echo ${module} | cut -d'.' -f2- | cut -c 2- | sed 's/\//+/g')

if [[ ! -f "$AZ_BATCH_TASK_WORKING_DIR/input/"${modifiedslug_with_sha}=${modified_module}".zip" ]]; then
    PIPESTATUS[0]=0
    ret=${PIPESTATUS[0]}
    exit $ret
fi

echo "================Installing the project: $(date)"
if [[ "$slug" == "apache/incubator-dubbo" ]]; then
    sudo chown -R $USER .
    mvn clean install -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$slug" == "caelum/vraptor" ]] || [[ "$slug" == "mozilla-metrics/akela" ]]; then
    echo "Cannot compile even in the latest master, some remote dependency is missing"
    exit 1
elif [[ "$slug" == "cucumber/cuke4duke" ]]; then
    sed -i '26s/2.8.1/2.10.4/' pom.xml
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$slug" == "fernandezpablo85/scribe-java" ]]; then
    sed -i '99s/</<!--/' pom.xml
    sed -i '115s/>/-->/' pom.xml
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$slug" == "spring-projects/spring-mvc-showcase" ]]; then
    echo "Cannot compile because the old SHA uses java7, and something is not compatible with java8"
    exit 1
elif [[ "$slug" == "spring-projects/spring-test-mvc" ]]; then
    echo "Repository not found in Github"
    exit 1
elif [[ "$slug" == "twitter/ambrose" ]]; then
    sed -i '74s/2.9.2/2.10.4/' pom.xml
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$slug" == "doanduyhai/Achilles" ]]; then
    sed -i "s?http://repo?https://repo?" pom.xml
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "logzio.sawmill-e493c2e" ]]; then
    sed -i '20,48d' sawmill-core/pom.xml
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "logzio.sawmill-84bb9f9" ]]; then
    sed -i '16,44d' sawmill-core/pom.xml
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$slug" == "apache/hadoop" ]]; then
    sudo apt-get install autoconf automake libtool curl make g++ unzip -y --allow-unauthenticated;
    wget -nv https://github.com/protocolbuffers/protobuf/releases/download/v2.5.0/protobuf-2.5.0.tar.gz;
    tar -zxvf protobuf-2.5.0.tar.gz;
    cd protobuf-2.5.0
    ./configure; make -j15;
    sudo make install;
    sudo ldconfig;
    cd ..
    if [[ "$modifiedslug_with_sha" == "apache.hbase-801fc05" ]]; then
	# Specifically for flaky tests in ./hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient because their forked VM can timeout otherwise
	sed -i '166s/.*/<\/additionalClasspathElements><forkedProcessTimeoutInSeconds>7200<\/forkedProcessTimeoutInSeconds>/' ./hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient/pom.xml
    fi
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$slug" == "openpojo/openpojo" ]]; then
    sed -i '70s/.*/return null;/' src/main/java/com/openpojo/random/generator/security/CredentialsRandomGenerator.java
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "nationalsecurityagency.timely-16a6223" ]]; then
    sed -i '314s/\${sureFireArgLine}//' server/pom.xml
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "nationalsecurityagency.timely-f912458" ]]; then
    sed -i '232s/\${sureFireArgLine}//' server/pom.xml
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "nationalsecurityagency.timely-3a8cbd3" ]]; then
    sed -i '466s/\${sureFireArgLine}//' pom.xml
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "pholser.junit-quickcheck-4480798" ]]; then
    sed -i "s/3.0.2/3.0.4/" pom.xml
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "tools4j.unix4j-1c9524d" ]]; then
    sed -i "s?@Ignore?//@Ignore?" $(find -name FindFileTimeDependentTest.java)
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "elasticjob.elastic-job-lite-3e5f30f" ]]; then
    # Removing tests that hang or is just invoking other test classes (the polluter is the same class as the victim)
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/AllTests.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/job/AllJobTests.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/job/api/AllApiTests.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/job/exception/AllExceptionTests.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/AllIntegrateTests.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/dataflow/sequence/OneOffSequenceDataFlowElasticJobTest.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/dataflow/sequence/StreamingSequenceDataFlowElasticJobTest.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/dataflow/throughput/OneOffThroughputDataFlowElasticJobTest.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/dataflow/throughput/StreamingThroughputDataFlowElasticJobForExecuteFailureTest.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/dataflow/throughput/StreamingThroughputDataFlowElasticJobForExecuteThrowsExceptionTest.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/dataflow/throughput/StreamingThroughputDataFlowElasticJobForMultipleThreadsTest.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/dataflow/throughput/StreamingThroughputDataFlowElasticJobForNotMonitorTest.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/dataflow/throughput/StreamingThroughputDataFlowElasticJobTest.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/simple/DisabledJobTest.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/simple/SimpleElasticJobTest.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/job/internal/AllInternalTests.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/job/plugin/sharding/strategy/AllPluginTests.java
    rm -rf elastic-job-core/src/test/java/com/dangdang/ddframe/reg/AllRegTests.java
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "alibaba.fastjson-01b2479" ]]; then
    sed -i '165s/4\.5/4\.12/' pom.xml
    sed -i 's?http://repo2.maven.org/maven2?https://repo.maven.apache.org/maven2?' pom.xml
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "alibaba.fastjson-197ba6c" ]]; then
    sed -i 's?net.sf.json.JSONException?com.alibaba.fastjson.JSONException?' src/main/java/com/alibaba/fastjson/parser/deserializer/OptionalCodec.java
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "alibaba.fastjson-29e0091" ]]; then
    sed -i "6,10d" pom.xml
    sed -i "5d" src/test/java/com/alibaba/json/bvt/serializer/DoubleFormatTest.java
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "alibaba.fastjson-2ce3c5e" ]]; then
    rm src/test/java/com/alibaba/json/bvt/serializer/NoneStringKeyTest_2.java src/test/java/com/alibaba/json/test/benchmark/jdk10/StringBenchmark.java src/test/java/com/alibaba/json/test/benchmark/jdk10/StringBenchmark_jackson.java
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "alibaba.fastjson-420d611" ]]; then
    sed -i "5d" src/test/java/com/alibaba/json/bvt/serializer/DoubleFormatTest.java
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "alibaba.fastjson-64d6ecb" ]]; then
    sed -i 's?net.sf.json.JSONException?com.alibaba.fastjson.JSONException?' src/main/java/com/alibaba/fastjson/parser/deserializer/OptionalCodec.java
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "alibaba.fastjson-da578f6" ]]; then
    sed -i '33d' src/main/java/com/alibaba/fastjson/parser/deserializer/ArrayListStringDeserializer.java
    sed -i '7d' src/main/java/com/alibaba/fastjson/parser/deserializer/ArrayListStringDeserializer.java
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "alibaba.fastjson-e8b094a" ]]; then
    sed -i "5d" src/test/java/com/alibaba/json/bvt/serializer/DoubleFormatTest.java
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "hexagonframework.spring-data-ebean-dd11b97" ]]; then
    # passing in dummy value as modifiedslug_with_sha to force setup-custom-maven.sh to run
    bash $dir/setup-custom-maven.sh "${RESULTSDIR}" "$dir" "$fullTestName" "." "$module"
    rm -rf pom.xml
    cp $dir/poms/${modifiedslug_with_sha}=pom.xml pom.xml
    echo "================Installing hexagon"
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "dropwizard.dropwizard-6e5c9c5" ]] && [[ $fullTestName == "io.dropwizard.logging.json.layout.JsonFormatterTest.testPrettyPrintNoLineSeparator" || $fullTestName == "io.dropwizard.logging.json.layout.JsonFormatterTest.testPrettyPrintWithLineSeparator" ]]; then
    rm ./dropwizard-json-logging/src/test/java/io/dropwizard/logging/json/layout/JsonFormatterTest.java
    cp $dir/files/${modifiedslug_with_sha}=${fullTestName}.java ./dropwizard-json-logging/src/test/java/io/dropwizard/logging/json/layout/JsonFormatterTest.java
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "apache.struts-13d9053" || "$modifiedslug_with_sha" == "apache.struts-0c543ae" ]] && [[ $fullTestName == "com.opensymphony.xwork2.validator.AnnotationActionValidatorManagerTest.testSkipUserMarkerActionLevelShortCircuit" || $fullTestName == "com.opensymphony.xwork2.validator.AnnotationActionValidatorManagerTest.testGetValidatorsForInterface" ]]; then
    rm ./core/src/test/java/com/opensymphony/xwork2/validator/AnnotationActionValidatorManagerTest.java
    cp $dir/files/${modifiedslug_with_sha}=${fullTestName}.java ./core/src/test/java/com/opensymphony/xwork2/validator/AnnotationActionValidatorManagerTest.java
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
else
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
fi

cd ~/
zip -r "${modifiedslug_with_sha}=${modified_module}".zip $projectname
cp "${modifiedslug_with_sha}=${modified_module}".zip ~/input
cd ~/$slug

ret=${PIPESTATUS[0]}
exit $ret