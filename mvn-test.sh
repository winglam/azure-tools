slug=$1
module=$2
testarg=$3
MVNOPTIONS=$4
ordering=$5
sha=$6
dir=$7

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"

echo "================Running maven test"
if [[ "$slug" == "dropwizard/dropwizard" ]]; then
    # dropwizard module complains about missing dependency if one uses -pl for some modules. e.g., ./dropwizard-logging
    mvn test -X -pl $module -am ${testarg} ${MVNOPTIONS} $ordering |& tee mvn-test.log
elif [[ "$modifiedslug_with_sha" == "hexagonframework.spring-data-ebean-dd11b97" ]]; then
    rm -rf pom.xml
    cp $dir/poms/${modifiedslug_with_sha}=pom.xml pom.xml
    mvn test -X -pl $module ${testarg} ${MVNOPTIONS} $ordering |& tee mvn-test.log
elif [[ "$slug" == "fhoeben/hsac-fitnesse-fixtures" ]]; then
    mvn test -X -pl $module ${testarg} ${MVNOPTIONS} $ordering -DskipITs |& tee mvn-test.log
else
    mvn test -X -pl $module ${testarg} ${MVNOPTIONS} $ordering |& tee mvn-test.log
fi

ret=${PIPESTATUS[0]}
exit $ret
