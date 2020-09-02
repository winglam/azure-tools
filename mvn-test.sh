slug=$1
module=$2
testarg=$3
MVNOPTIONS=$4
ordering=$5
sha=$6
dir=$7
fullTestName=$8

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"

# When updating this script, be sure that run_nondex_azure.sh (which doesn't call mvn-test.sh) is properly updated as needed

echo "================Running maven test"
mvn test -X -pl $module ${testarg} ${MVNOPTIONS} $ordering |& tee mvn-test.log

ret=${PIPESTATUS[0]}
exit $ret
