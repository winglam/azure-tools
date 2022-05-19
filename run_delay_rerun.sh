#!/bin/bash

if [[ $1 == "" ]]; then
    echo "arg1 - Path to CSV file with project,sha,test"
    exit
fi

repo=$(git rev-parse HEAD)
echo "script vers: $repo"
dir=$(pwd)
echo "script dir: $dir"
starttime=$(date)
echo "starttime: $starttime"

RESULTSDIR=~/output/
mkdir -p ${RESULTSDIR}

cd ~/
projfile=$1
rounds=$2
input_container=$3
line=$(head -n 1 $projfile)

echo "================Starting experiment for input: $line"
slug=$(echo ${line} | cut -d',' -f1 )
exp=$(echo ${line} | cut -d',' -f2)
runs=$(echo ${line} | cut -d',' -f3)

git clone https://github.com/winglam/run-projects-flakeflagger

cd run-projects-flakeflagger/
bash rerun.sh $slug $runs $exp

mv ~/results/ ${RESULTSDIR}/
mv ./results/ ${RESULTSDIR}/

endtime=$(date)
echo "endtime: $endtime"
