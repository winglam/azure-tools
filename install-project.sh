
slug=$1
MVNOPTIONS=$2
USER=$3
module=$4
sha=$5
dir=$6
fullTestName=$7

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"

echo "================Installing the project"
if [[ "$slug" == "apache/incubator-dubbo" ]]; then
    sudo chown -R $USER .
    mvn clean install -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
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
    sudo apt-get install autoconf automake libtool curl make g++ unzip;
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
elif [[ "$modifiedslug_with_sha" == "hexagonframework.spring-data-ebean-dd11b97" ]]; then
    rm -rf pom.xml
    cp $dir/poms/${modifiedslug_with_sha}=pom.xml pom.xml
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

ret=${PIPESTATUS[0]}
exit $ret
