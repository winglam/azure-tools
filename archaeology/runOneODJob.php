<?php
require("vendor/autoload.php");

$redis = new Redis();
$redis->connect('3.82.246.91');

// Use the us-east-2 region and latest version of each client.
$sharedConfig = [
    'profile' => 'default',
    'region' => 'us-east-1',
    'version' => 'latest'
];
// Create an SDK class used to share configuration across clients.
$sdk = new Aws\Sdk($sharedConfig);
// Use an Aws\Sdk class to create the S3Client object.
$s3Client = $sdk->createS3();

function getTestClass($fqn)
{
    return substr($fqn, 0, strrpos($fqn, "."));
}

function getTestMethod($fqn)
{
    return substr($fqn, strrpos($fqn, ".") + 1);
}

function formatForDTest($fqn)
{
    //Replace last . with a #
    return substr($fqn, 0, strrpos($fqn, ".")) . "#" . substr($fqn, strrpos($fqn, ".") + 1);
}

function formatForSort($fqn)
{
    return substr($fqn, strrpos($fqn, ".") + 1) . "(" . substr($fqn, 0, strrpos($fqn, ".")) . ")";
}

function formatForS3($fqn1,$fqn2){
	return escapeshellcmd($fqn1)."-".escapeshellcmd($fqn2);
}

function collectTestResults($fqn,$s3Key)
{
    global $s3Client;
    $tc = getTestClass($fqn);
    foreach (explode("\n", `find . -name TEST-$tc.xml`) as $f) {
        if ($f != "") {
            $d = simplexml_load_file($f);
            for ($i = 0; $i < count($d->testcase); $i++) {
                $name = $d->testcase[$i]->attributes()['name']->__toString();
                $fullName = $d->testcase[$i]->attributes()['classname']->__toString();
                $fullName .= "." . $name;
                if ($fullName == $fqn) {
                    try {
                        $result = $s3Client->putObject([
                            'Bucket' => 'flakylogs',
                            'Key' => "$s3Key",
                            'SourceFile' => $f]);
                    } catch (Exception $e) {
                        echo "Caught exception while uploading surefire xml: ", $e->getMessage(), "\n";
                    }
                    if (isset($d->testcase[$i]->failure) || isset($d->testcase[$i]->error)) {
                        return "ERROR";
                    } else {
                        return "OK";
                    }
                }
            }
        }
    }
    return "MISSING";
}
function execAndLog($note,$cmd){
    print "------------------------------------------------------------------------\n";
    print "$note\n";
    print "------------------------------------------------------------------------\n";

    print "Running: $cmd\n";
    $err = 0;
    $time = time();
    passthru($cmd." 2>&1",$err);
    $duration = time()- $time;
    print "Return code: $err. Duration: $duration seconds \n";
    return $err;
}
if(!is_dir("/usr/lib/jvm/jdk1.7.0_80")){
	execAndLog("Copy jdk7", "cp -r /experiment/jdk1.7.0_80 /usr/lib/jvm/jdk1.7.0_80");
}

$logFile = getcwd()."/execution.log";
$resultsFile = getcwd()."/results.csv";
$cwd = getcwd();
$firstRun = true;
while(true){
	chdir($cwd);
$job = $redis->lPop('od_queue');
$hostname = trim(`hostname`);
if($job == ""){
	$redis->sAdd("idle",$hostname);
	//die("no more to do!");
	//`sudo shutdown -h now`;
	$count = $redis->lLen("od_queue");
	while($count== 0){
		sleep(120);//2 minutes
		$count = $redis->lLen("od_queue");
	}
	$redis->sRem("idle",$hostname);
	`sudo reboot`;
}
$redis->sRem("idle",$hostname);
$statusString = $hostname.",".$job;
$redis->sAdd("od_in_progress",$statusString);

//fclose(STDERR);
ob_start();

//DEBUGGING from csv
//$jobs = file("jobs.csv");
//$job = $jobs[1];



$job = explode(",", $job);
$jobId = 1; //TODO From redis
$desc = $job[0];
$slug = $job[1];
$sha = $job[3];
$distanceFromFirstSha = $job[4];

$startTime = time();
print "------------------------------------------------------------------------\n";
print "OD flaky finding on project: $job[1] $job[3] ($distanceFromFirstSha past first SHA)\n";
print "Start time: ".date("r")."\n";
print "------------------------------------------------------------------------\n";

$mavenPath = "/Users/jon/Documents/GMU/Projects/firstShaFlaky/apache-maven-3.6.0/bin/mvn";
if(is_dir("/experiment/")){
    $mavenPath = "/experiment/flakyOD/apache-maven-3.6.0/bin/mvn -s /home/cc/.m2/settings.xml ";
}
$jobDir = "/tmp/flakyfinder/$job[1]";
if($firstRun){
	execAndLog("Clean up m2", "rm -rf /home/cc/.m2");
	execAndLog("Copy clean m2", "cp -r /experiment/maven-home /home/cc/.m2");
	$firstRun  =false;
}
execAndLog("Clean up job directory", "rm -rf $jobDir");
$localGit = getenv("HOME")."/flaky-repos";
if(!is_dir($localGit)){
    mkdir($localGit);
}
if(!is_dir("$localGit/$job[1]")){
    execAndLog("Cloning from GitHub", "git clone $job[2] $localGit/$job[1]");
}
execAndLog("Cloning from local repo", "git clone $localGit/$job[1] $jobDir");
chdir($jobDir);
$gitRes = "";
$res = execAndLog("Git checkout", "git checkout $job[3]");
if ($res != 0) {
    print "Bailing\n";
} else {
	if(!file_exists("pom.xml") && is_dir("lib")){
		print "cd lib;\n";
		chdir("lib");
	}
	if(strstr($job[1],"hexagonframework")){
		$pomContents = file_get_contents("pom.xml");
		if(!strstr($pomContents,"maven-surefire-plugin")){
			    $pomContents = str_replace("<plugins>",'
				     <plugins>
				          <plugin>
				                <groupId>org.apache.maven.plugins</groupId>
				                 <artifactId>maven-surefire-plugin</artifactId>
						<version>3.0.0-FLAKYSNAPSHOT</version>
					        </plugin>', $pomContents);
			        file_put_contents("pom.xml",$pomContents);
		}

	}
	$JAVA_HOME="JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/";
	if(strstr($job[1], "openpojo")){
		if(!is_dir("/usr/lib/jvm/jdk1.8.0_202")){
			execAndLog("Installing Oracle JDK 8 locally","sudo cp -r /experiment/jdk1.8.0_202/ /usr/lib/jvm/jdk1.8.0_202");
		}
		//$JAVA_HOME= "KP_IGNORE_COMPILE_ERRORS=true $JAVA_HOME";
		$JAVA_HOME="JAVA_HOME=/usr/lib/jvm/jdk1.8.0_202";
	}
    $res = execAndLog("Building project, no tests", "$JAVA_HOME $mavenPath -DskipTests -B -q install 2>&1");
	if($res != 0){
		print "Changing to Java 7 and trying again...\n";
		$JAVA_HOME="JAVA_HOME=/usr/lib/jvm/jdk1.7.0_80";
		$res = execAndLog("Building project, no tests", "$JAVA_HOME $mavenPath -DskipTests -B -q clean package -Dhttps.protocols=TLSv1.2");
	}
    $output = fopen($resultsFile, "w");
    fwrite($output, "slug,url,revision,distanceFromIDFSha,victim,polluter,victimFirstResult,polluterSecondResult,victimSecondResult,polluterFirstResult\n");
    for ($i = 5; $i < count($job); $i++) {
        $pair = explode(";", trim($job[$i]));
        fwrite($output, "$job[1],$job[2],$job[3],$pair[2],$pair[0],$pair[1],");
//    $cmd = "-Dtest=".formatForDTest($pair[0]).",".formatForDTest($pair[1]);
        print "Working on OD pair: $pair[0], $pair[1]\n";
        $cmd = "$JAVA_HOME timeout 5m $mavenPath -Djava.awt.headless=true -B -Dmaven.main.skip -Dmaven.javadoc.skip -Dcheckstyle.skip -Drat.skip -DfailIfNoTests=false -Dsurefire.methodRunOrder=flakyfinding -DtrimStackTrace=false -Dmaven.test.failure.ignore=true ";
	if(strstr($cmd,"1.7.0")){
		$cmd = "$cmd -Dhttps.protocols=TLSv1.2 ";
	}

        //Clean up any existing XML files
        execAndLog("Cleaning up any test results", "find . -name TEST-*.xml -delete");
        //The order that should pass
        $order = "-Dtest=" . formatForDTest($pair[0]) . "," . formatForDTest($pair[1]) . " -DflakyTestOrder='" . formatForSort($pair[0]) . "," . formatForSort($pair[1]) . "'";
        execAndLog("Running victim test FIRST, should pass", "$cmd $order test");
        $r1 = collectTestResults($pair[0], "od/$desc/$slug/$sha/".formatForS3($pair[0],$pair[1])."/$pair[0].xml");
        $r2 = collectTestResults($pair[1], "od/$desc/$slug/$sha/".formatForS3($pair[0],$pair[1])."/$pair[1].xml");
        print "VICTIM,POLLUTER -> $r1 $r2\n";

        execAndLog("Cleaning up any test results", "find . -name TEST-*.xml -delete");
        //The order that should fail
        $order = "-Dtest=" . formatForDTest($pair[0]) . "," . formatForDTest($pair[1]) . " -DflakyTestOrder='" . formatForSort($pair[1]) . "," . formatForSort($pair[0]) . "'";
        execAndLog("Running victim test SECOND, should fail", "$cmd $order test");

        $r3 = collectTestResults($pair[1], "od/$desc/$slug/$sha/".formatForS3($pair[1],$pair[0])."/$pair[1].xml");
        $r4 = collectTestResults($pair[0], "od/$desc/$slug/$sha/".formatForS3($pair[1],$pair[0])."/$pair[0].xml");
        print "POLLUTER,VICTIM -> $r3 $r4\n";

        fwrite($output, "$r1,$r2,$r4,$r3\n");
        //$redis->lPush("od_job_result","$job[0],$job[1],$job[2],$job[3],$pair[0],$pair[1],$r1,$r2,$r4,$r3");
    }
    fclose($output);
    execAndLog("Clean up java processes","killall -9 java");
}
print "------------------------------------------------------------------------\n";
print "ODFlakyFinder $sha job done\n";
print "End time: ".date("r"). " (".(time()-$startTime)." seconds)\n";
print "------------------------------------------------------------------------\n";

print "Storing results to Redis...\n";
print "Uploading to S3: $logFile, $resultsFile\n";
file_put_contents($logFile, ob_get_flush());
//Stuff the results into Redis, save logs to S3
try {
    $result = $s3Client->putObject([
        'Bucket' => 'flakylogs',
        'Key' => "od/$desc/$slug/$sha/log.txt",
        'SourceFile' => $logFile]);
    $result = $s3Client->putObject([
        'Bucket' => 'flakylogs',
        'Key' => "od/$desc/$slug/$sha/result.csv",
        'SourceFile' => $resultsFile]);
} catch (Exception $e) {
    echo "Caught exception: ", $e->getMessage(), "\n";
}
`rm -rf /tmp/flakyfinder`;
$redis->sAdd("od_done",$statusString);
$redis->sRem("od_in_progress",$statusString);

}
