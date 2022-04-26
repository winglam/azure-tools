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

git clone https://github.com/denini08/run-projects-flakeflagger

cd run-projects-flakeflagger/
bash run.sh $slug $runs $exp

echo "================Setup to emacs and maven path"
sudo apt-get update -y --allow-unauthenticated
sudo apt-get install emacs -y --allow-unauthenticated
sudo apt-get install tmux -y --allow-unauthenticated
sudo apt-get install xclip -y --allow-unauthenticated

mv ~/results/ ${RESULTSDIR}/
mv ./results/ ${RESULTSDIR}/

endtime=$(date)
echo "endtime: $endtime"
