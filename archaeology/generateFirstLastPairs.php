<?php
ini_set('memory_limit', '1G');

$desc = date("Y-m-d-ga");
$desc = "2020-04-21-9am";
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

$testToSha = array();
foreach (file("all-flaky-idf-sha.csv") as $l) {
    $d = explode(",", trim($l));
    $testToSha[$d[2]] = array("sha" => $d[1], "URL" => $d[0]);
}
$ran = array();
foreach (file("generated/shasRunToDate.txt") as $l) {
    $l = trim($l);
    $ran[$l] = $l;
}
$SHAjobs = array();
foreach (file("idf_sha_all-polluter-cleaner.csv") as $l) {
    if (strstr($l, "type_victim"))
        continue;
    //victim/brittle,polluter/state-setter,potential_cleaner,type_victim_or_brittle
    $d = explode(",", trim($l));
    if (strstr($l, "AutobahnServerResults"))
        continue;

    $t1 = $d[0];
    $t1 = substr($t1, 0, strrpos($t1, ".")) . "#" . substr($t1, 1 + strrpos($t1, '.'));
    $t2 = $d[1];
    $t2 = substr($t2, 0, strrpos($t2, ".")) . "#" . substr($t2, 1 + strrpos($t2, '.'));

    $s1 = loadSHAs($t1);
    $s2 = loadSHAs($t2);
    $url = $testToSha[$d[0]]['URL'];
    $idfSha = $testToSha[$d[0]]['sha'];
    $slug = getSlug($url);
    if ($s1 == null || $s2 == null)
        continue;
    //Find the first SHA that has both
    $i1 = null;
    $i2 = null;

    //Now, find all SHAs that contain both tests
    $shasIntersected = false;
    $numSHAsOutput = 0;
    foreach ($s1['bySha'] as $sha => $dat) {
        if (isset($s2['bySha'][$sha])) {
//            if ($idfSha == $sha) {
            if ($numSHAsOutput < 500 || $idfSha == $sha) {
                $shasIntersected = true;
                if (!isset($SHAjobs[$sha]))
                    $SHAjobs[$sha] = array("jobs" => array(), "distanceFromFirstCommit" => $numSHAsOutput, "meta" => $desc . "," . $slug . ",$url,$sha");
                $SHAjobs[$sha]['jobs'][$t1 . $t2] = str_replace("#", ".", $dat['test'] . ";" . $s2['bySha'][$sha]['test']) . ";" . $numSHAsOutput;
                if ($numSHAsOutput < $SHAjobs[$sha]["distanceFromFirstCommit"])
                    $SHAjobs[$sha]["distanceFromFirstCommit"] = $numSHAsOutput;
            }
            $numSHAsOutput++;
        }
    }
    if (!$shasIntersected) {
        print "Couldn't find interescting SHAs for $t1 $t2\n";
        die();
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
        print "$job\n";
        $redis->rPush("od_queue", $job);
    }
}
