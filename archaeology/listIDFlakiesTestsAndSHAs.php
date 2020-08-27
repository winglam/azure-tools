<?php
function getSlug($proj)
{
    return str_replace("/", "-", str_replace("https://github.com/", "", $proj));
}

//get victim to sha
$testToSha = array();
foreach(file("all-flaky-idf-sha.csv") as $l){
    $d = explode(",",trim($l));
    $testToSha[$d[2]] = array("sha" => $d[1], "URL"=>$d[0]);
}
foreach (file("idf_sha_all-polluter-cleaner.csv") as $l) {
    if(strstr($l,"victim/brittle"))
        continue;
    $d = explode(",", trim($l));
    //Get victim info
    $info = $testToSha[$d[0]];
    $sha = $info['sha'];
    if (!isset($pairsToRun[$sha])) {
        $pairsToRun[$sha] = array("URL" => $info['URL'],
            "slug" => getSlug($info['URL']),
            "pairs" => array());
    }
    $proj = getSlug($info['URL']);
    $pairsToRun[$sha]['pairs'][$d[0]] = 1;
    $pairsToRun[$sha]['pairs'][$d[1]] = 1;
}
foreach($pairsToRun as $sha => $pair){
    if(!file_exists("experiments/$pair[slug]")){
        `git clone $pair[URL] experiments/$pair[slug]`;
//        print_R($pair);
//        die();
    }
    foreach($pair['pairs'] as $test => $none){
        print getcwd()."/experiments/$pair[slug]/.git,$sha,$test\n";
    }
}
//Save this file to id_flakies_tests.csv
