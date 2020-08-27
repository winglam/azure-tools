slug=$1
module=$2
testarg=$3
MVNOPTIONS=$4

echo "================Running maven test"
if [[ "$slug" == "dropwizard/dropwizard" ]]; then
    # dropwizard module complains about missing dependency if one uses -pl for some modules. e.g., ./dropwizard-logging
    mvn test -pl $module -am ${testarg} ${MVNOPTIONS} |& tee mvn-test.log
elif [[ "$slug" == "fhoeben/hsac-fitnesse-fixtures" ]]; then
    mvn test -pl $module ${testarg} ${MVNOPTIONS} -DskipITs |& tee mvn-test.log
else
    mvn test -pl $module ${testarg} ${MVNOPTIONS} |& tee mvn-test.log
fi

ret=${PIPESTATUS[0]}
exit $ret
