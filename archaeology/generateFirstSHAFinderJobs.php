<?php
ini_set('memory_limit', '1G');

$desc = date("Y-m-d-ga");
//$desc = "2020-04-21-9am";
$redis = new Redis();
$redis->connect('3.82.246.91');
date_default_timezone_set("America/New_York");
function getSlug($proj)
{
    return str_replace("/", "-", str_replace("https://github.com/", "", $proj));
}

function loadSHAs($test)
{
    $shas = array();
    if (!file_exists("testHistory/$test")) {
        print "Missing test info for $test\n";
        return null;
    }
    foreach (file("testHistory/$test") as $l) {
        $d = explode(",", trim($l));
        $shas['byIndex'][$d[0]] = array("SHA" => $d[1], "test" => $d[2], "commitsSinceIntroduced" => $d[0]);
        $shas['bySha'][$d[1]] = $shas['byIndex'][$d[0]];
    }
    return $shas;
}

$SHAjobs = array();
foreach (file("id_flakies_tests.csv") as $l) {
    //url,idfSha,test
    $d = explode(",", trim($l));

    $t1 = $d[2];
    $t1 = substr($t1, 0, strrpos($t1, ".")) . "#" . substr($t1, 1 + strrpos($t1, '.'));

    $s1 = loadSHAs($t1);
    $url = $d[0];
    $idfSha = $d[1];
    $slug = getSlug($url);
//    if(!strstr($url,"jfreechart"))
//        continue;
    if ($s1 == null)
        continue;

    //Now, find all SHAs that contain both tests
    $numSHAsOutput = 0;
    foreach ($s1['bySha'] as $sha => $dat) {
//            if ($idfSha == $sha) {
        if ($numSHAsOutput < 20 || $idfSha == $sha) {
            if (!isset($SHAjobs[$sha]))
                $SHAjobs[$sha] = array("jobs" => array(), "distanceFromFirstCommit" => $numSHAsOutput, "meta" => $desc . "," . $slug . ",$url,$sha");
            $SHAjobs[$sha]['jobs'][$t1] = str_replace("#", ".", $dat['test'] . ";" . $numSHAsOutput);
            if ($numSHAsOutput < $SHAjobs[$sha]["distanceFromFirstCommit"])
                $SHAjobs[$sha]["distanceFromFirstCommit"] = $numSHAsOutput;
        }
        $numSHAsOutput++;
    }
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
