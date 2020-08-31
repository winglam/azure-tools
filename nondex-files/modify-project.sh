#!/bin/bash

if [ "$1" == "" ]; then
    echo "arg1 - the path to the project, where high-level pom.xml is"
    exit
fi

crnt=`pwd`
working_dir=`dirname $0`
project_path=$1
option=$2

cd ${project_path}
project_path=`pwd`
cd - > /dev/null

cd ${working_dir}

javac PomFile.java
find ${project_path} -name pom.xml | java -cp . PomFile ${option}

cd ${crnt}
