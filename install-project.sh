#!/bin/bash

slug=$1
MVNOPTIONS=$2
USER=$3
module=$4
sha=$5
dir=$6
fullTestName=$7
RESULTSDIR=$8
input_container=$9

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"
modified_module=$(echo ${module} | sed 's?\./??g' | sed 's/\//+/g')
modified_slug_module="${modifiedslug_with_sha}=${modified_module}"

#We expect that clone-project.sh script is run before this script. If the project zip exists, 
#then clone-project.sh should have unzipped an installed version of the project already. 
#Therefore, we do not install the project again and we use the already installed and zipped project

if [[ -f "$AZ_BATCH_TASK_WORKING_DIR/$input_container/projects/$modified_slug_module.zip" ]]; then
    echo "Project/sha/module zip already exist in input container and should be unzipped from clone-project.sh already. Skipping installation"
    exit 0
else
    echo "$AZ_BATCH_TASK_WORKING_DIR/$input_container/projects/$modified_slug_module.zip not found. Installing project."
fi

command="mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log"

echo "================Installing the project: $(date)"
if [[ "$slug" == "apache/incubator-dubbo" ]]; then
    sudo chown -R $USER .
    command=$(mvn clean install -DskipTests ${MVNOPTIONS} |& tee mvn-install.log)
elif [[ "$slug" == "caelum/vraptor" ]] || [[ "$slug" == "mozilla-metrics/akela" ]]; then
    echo "Cannot compile even in the latest master, some remote dependency is missing"
    exit 1
elif [[ "$slug" == "cucumber/cuke4duke" ]]; then
    sed -i '26s/2.8.1/2.10.4/' pom.xml
elif [[ "$slug" == "fernandezpablo85/scribe-java" ]]; then
    sed -i '99s/</<!--/' pom.xml
    sed -i '115s/>/-->/' pom.xml
elif [[ "$slug" == "spring-projects/spring-mvc-showcase" ]]; then
    echo "Cannot compile because the old SHA uses java7, and something is not compatible with java8"
    exit 1
elif [[ "$slug" == "spring-projects/spring-test-mvc" ]]; then
    echo "Repository not found in Github"
    exit 1
elif [[ "$slug" == "twitter/ambrose" ]]; then
    sed -i '74s/2.9.2/2.10.4/' pom.xml
elif [[ "$slug" == "doanduyhai/Achilles" ]]; then
    sed -i "s?http://repo?https://repo?" pom.xml
elif [[ "$modifiedslug_with_sha" == "logzio.sawmill-e493c2e" ]]; then
    sed -i '20,48d' sawmill-core/pom.xml
elif [[ "$modifiedslug_with_sha" == "logzio.sawmill-84bb9f9" ]]; then
    sed -i '16,44d' sawmill-core/pom.xml
elif [[ "$modifiedslug_with_sha" == "tootallnate.java-websocket-fa3909c" ]]; then 
    rm -f src/test/java/org/java_websocket/AllTests.java
    rm -f src/test/java/org/java_websocket/client/AllClientTests.java
    rm -f src/test/java/org/java_websocket/drafts/AllDraftTests.java
    rm -f src/test/java/org/java_websocket/issues/AllIssueTests.java
    rm -f src/test/java/org/java_websocket/misc/AllMiscTests.java
    rm -f src/test/java/org/java_websocket/protocols/AllProtocolTests.java
    rm -f src/test/java/org/java_websocket/framing/AllFramingTests.java
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
elif [[ "$slug" == "openpojo/openpojo" ]]; then
    #the commented rows were in the run_cloc_azure.sh
    #wget https://files-cdn.liferay.com/mirrors/download.oracle.com/otn-pub/java/jdk/7u80-b15/jdk-7u80-linux-x64.tar.gz
    #tar -zxf jdk-7u80-linux-x64.tar.gz
    #dir=$(pwd)
    #export JAVA_HOME=$dir/jdk1.7.0_80/
    #MVNOPTIONS="${MVNOPTIONS} -Dhttps.protocols=TLSv1.2"
    #mvn clean install -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
    sed -i '70s/.*/return null;/' src/main/java/com/openpojo/random/generator/security/CredentialsRandomGenerator.java
elif [[ "$modifiedslug_with_sha" == "nationalsecurityagency.timely-16a6223" ]]; then
    sed -i '314s/\${sureFireArgLine}//' server/pom.xml
elif [[ "$modifiedslug_with_sha" == "nationalsecurityagency.timely-f912458" ]]; then
    sed -i '232s/\${sureFireArgLine}//' server/pom.xml
elif [[ "$modifiedslug_with_sha" == "nationalsecurityagency.timely-3a8cbd3" ]]; then
    sed -i '466s/\${sureFireArgLine}//' pom.xml
elif [[ "$modifiedslug_with_sha" == "pholser.junit-quickcheck-4480798" ]]; then
    sed -i "s/3.0.2/3.0.4/" pom.xml
elif [[ "$modifiedslug_with_sha" == "tools4j.unix4j-1c9524d" ]]; then
    sed -i "s?@Ignore?//@Ignore?" $(find -name FindFileTimeDependentTest.java)
elif [[ "$modifiedslug_with_sha" == "elasticjob.elastic-job-lite-3e5f30f" ]]; then
    # Removing tests that hang or is just invoking other test classes (the polluter is the same class as the victim)
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/AllTests.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/job/AllJobTests.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/job/api/AllApiTests.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/job/exception/AllExceptionTests.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/AllIntegrateTests.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/dataflow/sequence/OneOffSequenceDataFlowElasticJobTest.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/dataflow/sequence/StreamingSequenceDataFlowElasticJobTest.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/dataflow/throughput/OneOffThroughputDataFlowElasticJobTest.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/dataflow/throughput/StreamingThroughputDataFlowElasticJobForExecuteFailureTest.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/dataflow/throughput/StreamingThroughputDataFlowElasticJobForExecuteThrowsExceptionTest.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/dataflow/throughput/StreamingThroughputDataFlowElasticJobForMultipleThreadsTest.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/dataflow/throughput/StreamingThroughputDataFlowElasticJobForNotMonitorTest.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/dataflow/throughput/StreamingThroughputDataFlowElasticJobTest.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/simple/DisabledJobTest.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/job/integrate/std/simple/SimpleElasticJobTest.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/job/internal/AllInternalTests.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/job/plugin/sharding/strategy/AllPluginTests.java
    rm -f elastic-job-core/src/test/java/com/dangdang/ddframe/reg/AllRegTests.java
elif [[ "$modifiedslug_with_sha" == "elasticjob.elastic-job-lite-b022898" ]]; then
    # Removing test classes that are just invoking other test classes
    rm -f elastic-job-lite-core/src/test/java/io/elasticjob/lite/AllLiteCoreTests.java
    rm -f elastic-job-lite-core/src/test/java/io/elasticjob/lite/api/AllApiTests.java
    rm -f elastic-job-lite-core/src/test/java/io/elasticjob/lite/config/AllConfigTests.java
    rm -f elastic-job-lite-core/src/test/java/io/elasticjob/lite/context/AllContextTests.java
    rm -f elastic-job-lite-core/src/test/java/io/elasticjob/lite/event/AllEventTests.java
    rm -f elastic-job-lite-core/src/test/java/io/elasticjob/lite/executor/AllExecutorTests.java
    rm -f elastic-job-lite-core/src/test/java/io/elasticjob/lite/exception/AllExceptionTests.java
    rm -f elastic-job-lite-core/src/test/java/io/elasticjob/lite/integrate/AllIntegrateTests.java
    rm -f elastic-job-lite-core/src/test/java/io/elasticjob/lite/internal/AllInternalTests.java
    rm -f elastic-job-lite-core/src/test/java/io/elasticjob/lite/reg/AllRegTests.java
    rm -f elastic-job-lite-core/src/test/java/io/elasticjob/lite/statistics/AllStatisticsTests.java
    rm -f elastic-job-lite-core/src/test/java/io/elasticjob/lite/util/AllUtilTests.java
elif [[ "$modifiedslug_with_sha" == "alibaba.fastjson-01b2479" ]]; then
    sed -i '165s/4\.5/4\.12/' pom.xml
    sed -i 's?http://repo2.maven.org/maven2?https://repo.maven.apache.org/maven2?' pom.xml
elif [[ "$modifiedslug_with_sha" == "alibaba.fastjson-197ba6c" ]]; then
    sed -i 's?net.sf.json.JSONException?com.alibaba.fastjson.JSONException?' src/main/java/com/alibaba/fastjson/parser/deserializer/OptionalCodec.java
elif [[ "$modifiedslug_with_sha" == "alibaba.fastjson-29e0091" ]]; then
    sed -i "6,10d" pom.xml
    sed -i "5d" src/test/java/com/alibaba/json/bvt/serializer/DoubleFormatTest.java
elif [[ "$modifiedslug_with_sha" == "alibaba.fastjson-2ce3c5e" ]]; then
    rm src/test/java/com/alibaba/json/bvt/serializer/NoneStringKeyTest_2.java src/test/java/com/alibaba/json/test/benchmark/jdk10/StringBenchmark.java src/test/java/com/alibaba/json/test/benchmark/jdk10/StringBenchmark_jackson.java
elif [[ "$modifiedslug_with_sha" == "alibaba.fastjson-420d611" ]]; then
    sed -i "5d" src/test/java/com/alibaba/json/bvt/serializer/DoubleFormatTest.java
elif [[ "$modifiedslug_with_sha" == "alibaba.fastjson-64d6ecb" ]]; then
    sed -i 's?net.sf.json.JSONException?com.alibaba.fastjson.JSONException?' src/main/java/com/alibaba/fastjson/parser/deserializer/OptionalCodec.java
elif [[ "$modifiedslug_with_sha" == "alibaba.fastjson-da578f6" ]]; then
    sed -i '33d' src/main/java/com/alibaba/fastjson/parser/deserializer/ArrayListStringDeserializer.java
    sed -i '7d' src/main/java/com/alibaba/fastjson/parser/deserializer/ArrayListStringDeserializer.java
elif [[ "$modifiedslug_with_sha" == "alibaba.fastjson-e8b094a" ]]; then
    sed -i "5d" src/test/java/com/alibaba/json/bvt/serializer/DoubleFormatTest.java
elif [[ "$modifiedslug_with_sha" == "hexagonframework.spring-data-ebean-dd11b97" ]]; then
    # passing in dummy value as modifiedslug_with_sha to force setup-custom-maven.sh to run
    bash $dir/setup-custom-maven.sh "${RESULTSDIR}" "$dir" "$fullTestName" "." "$module"
    rm -rf pom.xml
    cp $dir/poms/${modifiedslug_with_sha}=pom.xml pom.xml
    echo "================Installing hexagon"
elif [[ "$modifiedslug_with_sha" == "dropwizard.dropwizard-6e5c9c5" ]] && [[ $fullTestName == "io.dropwizard.logging.json.layout.JsonFormatterTest.testPrettyPrintNoLineSeparator" || $fullTestName == "io.dropwizard.logging.json.layout.JsonFormatterTest.testPrettyPrintWithLineSeparator" ]]; then
    rm ./dropwizard-json-logging/src/test/java/io/dropwizard/logging/json/layout/JsonFormatterTest.java
    cp $dir/files/${modifiedslug_with_sha}=${fullTestName}.java ./dropwizard-json-logging/src/test/java/io/dropwizard/logging/json/layout/JsonFormatterTest.java
elif [[ "$modifiedslug_with_sha" == "apache.struts-13d9053" || "$modifiedslug_with_sha" == "apache.struts-0c543ae" ]] && [[ $fullTestName == "com.opensymphony.xwork2.validator.AnnotationActionValidatorManagerTest.testSkipUserMarkerActionLevelShortCircuit" || $fullTestName == "com.opensymphony.xwork2.validator.AnnotationActionValidatorManagerTest.testGetValidatorsForInterface" ]]; then
    rm ./core/src/test/java/com/opensymphony/xwork2/validator/AnnotationActionValidatorManagerTest.java
    cp $dir/files/${modifiedslug_with_sha}=${fullTestName}.java ./core/src/test/java/com/opensymphony/xwork2/validator/AnnotationActionValidatorManagerTest.java
elif [[ "$slug" == "apache/servicecomb-pack" ]]; then
    cd $module
fi

eval "$command"
echo "$command" |& tee mvn-install-command.sh
ret=${PIPESTATUS[0]}

if [[ $ret == 0 ]]; then
    cd $AZ_BATCH_TASK_WORKING_DIR
    zip -rq $modified_slug_module.zip ${slug%/*}
    if [[ ! -f "$input_container/dependencies/dependencies_$modified_slug_module.zip" ]]; then
        cd dependencies
        zip -rq "dependencies_$modified_slug_module".zip dependencies_$modified_slug_module
        mv "dependencies_$modified_slug_module".zip $AZ_BATCH_TASK_WORKING_DIR/$input_container/dependencies
        cd $AZ_BATCH_TASK_WORKING_DIR
    fi
    mkdir -p ~/$input_container/projects && mv $modified_slug_module.zip ~/$input_container/projects
    echo "$AZ_BATCH_TASK_WORKING_DIR/$input_container/projects/"$modified_slug_module".zip is created and saved"
    cd ~/$slug
fi

exit $ret
