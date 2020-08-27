<?php
ini_set('memory_limit', '1G');

date_default_timezone_set("America/New_York");
$desc = date("Y-m-d-ga");
//$desc = "2020-04-21-9am";
$redis = new Redis();
$redis->connect('3.82.246.91');
$redis->auth("zm5bjgjtAWwxv");
function getSlug($proj)
{
    return str_replace("/", "-", str_replace("https://github.com/", "", $proj));
}

function loadSHAs($test)
{
    $shas = array();
    if (!file_exists("testHistory/$test")) {
        print "Missing test info for $test\n";
        die();
        return null;
    }
    foreach (file("testHistory/$test") as $l) {
        $d = explode(",", trim($l));
        $shas['byIndex'][$d[0]] = array("SHA" => $d[1], "test" => $d[2], "commitsSinceIntroduced" => $d[0]);
        $shas['bySha'][$d[1]] = $shas['byIndex'][$d[0]];
    }
    if(count($shas) == 0){
        die("Unable to get sha info for $test");
    }
    return $shas;
}

$testToSha = array();
$SHAjobs = array();
foreach (file("510-tests-idf-sha-isolation.csv") as $l) {
    //https://github.com/alien4cloud/alien4cloud,eb57d0feca6c37e0a4aafc3feef494e43e02ecda,alien4cloud.security.LdapAuthenticationProviderTest.testLdapUserImport,OD
    $d = explode(",", trim($l));

    $t1 = $d[2];
    $t1 = substr($t1, 0, strrpos($t1, ".")) . "#" . substr($t1, 1 + strrpos($t1, '.'));

    $s1 = loadSHAs($t1);
    $url = $d[0];
    $idfSha = $d[1];
    $slug = getSlug($url);
    if ($s1 == null)
        continue;
    //Find the first SHA that has it
    $i1 = null;

    $sha = $idfSha;
    if (!isset($SHAjobs[$sha]))
        $SHAjobs[$sha] = array("jobs" => array(), "distanceFromFirstCommit" => 100000, "meta" => $desc . "," . $slug . ",$url,$sha");
    $SHAjobs[$sha]['jobs'][$t1] = str_replace("#", ".", $t1 . ";10000");

    $dat = $s1['byIndex'][0];
    $sha = $dat['SHA'];

    if (!isset($SHAjobs[$sha]))
        $SHAjobs[$sha] = array("jobs" => array(), "distanceFromFirstCommit" => 0, "meta" => $desc . "," . $slug . ",$url,$sha");
    $SHAjobs[$sha]['jobs'][$t1] = str_replace("#", ".", $dat['test'] . ";0");
    if (0 < $SHAjobs[$sha]["distanceFromFirstCommit"])
        $SHAjobs[$sha]["distanceFromFirstCommit"] = 0;
}
$jobsByDistance = array();
foreach ($SHAjobs as $sha => $dat) {
    $job = $dat['meta'] . "," . $dat['distanceFromFirstCommit'];
    foreach ($dat['jobs'] as $j) {
        $job .= ",$j";
    }
    $jobsByDistance[$dat['distanceFromFirstCommit']][] = $job;
}
foreach ($jobsByDistance as $dist => $jobs) {
    foreach ($jobs as $job) {
//        print "$job\n";
        $redis->rPush("od_queue", $job);
    }
}
