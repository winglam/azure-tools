
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
elif [[ "$slug" == "openpojo/openpojo" ]]; then
    wget https://files-cdn.liferay.com/mirrors/download.oracle.com/otn-pub/java/jdk/7u80-b15/jdk-7u80-linux-x64.tar.gz
    tar -zxf jdk-7u80-linux-x64.tar.gz
    dirop=$(pwd)
    export JAVA_HOME=$dirop/jdk1.7.0_80/
    MVNOPTIONS="${MVNOPTIONS} -Dhttps.protocols=TLSv1.2"
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
else
    mvn clean install -am -pl $module -DskipTests ${MVNOPTIONS} |& tee mvn-install.log
fi

ret=${PIPESTATUS[0]}
exit $ret
