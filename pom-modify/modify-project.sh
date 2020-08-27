#!/bin/bash

if [[ $1 == "" ]]; then
    echo "arg1 - the path to the project, where high-level pom.xml is"
    echo "arg2 - (Optional) Plugin type (testrunner, rvPredict, wiretap, or modifyOrder)"
    echo "arg3 - (Optional) Fully qualified test name when using rvPredict"
    echo "arg4 - (Optional) Path to rvPredict jar"
    exit
fi

pluginType=$2

if [[ $pluginType == "" ]]; then
  pluginType="testrunner"
else
  if { [[ $3 == "" ]] || [[ $4 == "" ]]; } && [[ $2 == "rvPredict" ]]; then
    echo "arg1 - the path to the project, where high-level pom.xml is"
    echo "arg2 - (Optional) Plugin type (testrunner, rvPredict, wiretap, or modifyOrder)"
    echo "arg3 - (Optional) Fully qualified test name when using rvPredict"
    echo "arg4 - (Optional) Path to rvPredict jar"
    exit
  else
    testName=$3
    jarPath=$4
  fi
fi

crnt=`pwd`
working_dir=`dirname $0`
project_path=$1

cd ${project_path}
project_path=`pwd`
cd - > /dev/null

cd ${working_dir}

function process_poms
{
    while read pom; do
        ./modify-pom.sh ${pom}
    done
}

#find ${project_path} -name pom.xml | process_poms
javac PomFile.java
find ${project_path} -name pom.xml | grep -v "src/" | java PomFile ${pluginType} ${testName} ${jarPath}
rm -f PomFile.class

cd ${crnt}
