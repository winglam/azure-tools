RESULTSDIR=$1
dir=$2
fullTestName=$3
modified_slug_module=$4
use_zip=$5

cd $AZ_BATCH_TASK_WORKING_DIR

if [[ "$use_zip" == "true" ]]; then
    if [ ! -d $AZ_BATCH_TASK_WORKING_DIR/custom-maven-surefire-m2 ]; then
	wget http://mir.cs.illinois.edu/winglam/personal/custom-maven-surefire-m2.zip
	unzip -q custom-maven-surefire-m2.zip
    fi
    cp -r $AZ_BATCH_TASK_WORKING_DIR/custom-maven-surefire-m2/* dependencies/dependencies_${modified_slug_module}/
elif [[ ! -d "maven-surefire" ]]; then
    echo "================Setting up maven-surefire"
    git clone https://github.com/TestingResearchIllinois/maven-surefire.git
    cd maven-surefire/
    echo "maven-surefire version: $(git rev-parse HEAD)"
    mvn install -DskipTests -Drat.skip |& tee surefire-install.log
    mv surefire-install.log ${RESULTSDIR}
    mv surefire-changing-maven-extension/target/surefire-changing-maven-extension-1.0-SNAPSHOT.jar $AZ_BATCH_TASK_WORKING_DIR/apache-maven/lib/ext/
fi
