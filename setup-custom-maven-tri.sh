RESULTSDIR=$1
dir=$2
fullTestName=$3
modifiedslug_with_sha=$4
module=$5

echo "================Setting up maven-surefire"
cd ~/
git clone https://github.com/TestingResearchIllinois/maven-surefire.git
cd maven-surefire/
echo "maven-surefire version: $(git rev-parse HEAD)"
mvn install -DskipTests -Drat.skip |& tee surefire-install.log
mv surefire-install.log ${RESULTSDIR}
mv surefire-changing-maven-extension/target/surefire-changing-maven-extension-1.0-SNAPSHOT.jar ~/apache-maven/lib/ext/
