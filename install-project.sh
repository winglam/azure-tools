
slug=$1
MVNOPTIONS=$2
USER=$3
module=$4
sha=$5
dir=$6

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"

echo "================Installing the project"
if [[ "$slug" == "apache/incubator-dubbo" ]]; then
    sudo chown -R $USER .
    mvn clean install -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "doanduyhai.achilles-e3099bd" ]]; then
    sed -i "s?http://repo?https://repo?" pom.xml
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "logzio.sawmill-e493c2e" ]]; then
    sed -i '20,48d' sawmill-core/pom.xml
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "apache.hadoop-cc2babc" ]]; then
    sudo apt-get install autoconf automake libtool curl make g++ unzip;
    wget -nv https://github.com/protocolbuffers/protobuf/releases/download/v2.5.0/protobuf-2.5.0.tar.gz;
    tar -zxvf protobuf-2.5.0.tar.gz;
    cd protobuf-2.5.0
    ./configure; make -j15;
    sudo make install;
    sudo ldconfig;
    cd ..
    # Specifically for flaky tests in ./hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient because their forked VM can timeout otherwise
    sed -i '166s/.*/<\/additionalClasspathElements><forkedProcessTimeoutInSeconds>0<\/forkedProcessTimeoutInSeconds>/' ./hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient/pom.xml
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
elif [[ "$modifiedslug_with_sha" == "nationalsecurityagency.timely-3a8cbd3" ]]; then
    sed -i '466s/\${sureFireArgLine}//' pom.xml
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
else
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
fi

ret=${PIPESTATUS[0]}
exit $ret
