RESULTSDIR=$1
dir=$2

echo "================Setting up maven-surefire"
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
