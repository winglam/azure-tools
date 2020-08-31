RESULTSDIR=$1
dir=$2
fullTestName=$3
modifiedslug_with_sha=$4

echo "================Setting up maven-surefire"

if [[ "$modifiedslug_with_sha" == "spring-projects.spring-boot-daa3d45" ]] && [[ "$fullTestName" == "org.springframework.boot.test.autoconfigure.properties.AnnotationsPropertySourceTests.propertiesFromMultipleMetaAnnotationsAreMappedUsingTheirOwnPropertyMapping" || "$fullTestName" == "org.springframework.boot.test.mock.mockito.ResetMocksTestExecutionListenerTests.test002" ]]; then
    echo "Skipping setup of maven-surefire for $modifiedslug_with_sha $fullTestName"
    exit 0
fi

cd ~/
git clone https://github.com/gmu-swe/maven-surefire.git
cd maven-surefire/
git checkout test-method-sorting
mvn install -DskipTests -Drat.skip |& tee surefire-install.log
mv surefire-install.log ${RESULTSDIR}

echo "================Setting up maven-extension"
cd $dir/archaeology/archaeology-maven-extension/
mvn install -DskipTests |& tee extension-install.log
mv extension-install.log ${RESULTSDIR}
mv target/surefire-changing-maven-extension-1.0-SNAPSHOT.jar ~/apache-maven/lib/ext/
