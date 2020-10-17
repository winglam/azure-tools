#!/bin/bash

ARTIFACT_ID="idflakies"
ARTIFACT_VERSION="1.0.2"
CONFIGURATION_CLASS="edu.illinois.cs.dt.tools.detection.DetectorPlugin"
TESTRUNNER_ARTIFACT_VERSION="1.0"

if [[ $1 == "" ]]; then
    echo "arg1 - the path to the project, where high-level pom.xml is"
    echo "arg2 - (Optional) Custom version for the artifact (e.g., 1.0.2, 1.0.3-SNAPSHOT). Default is $ARTIFACT_VERSION"
    echo "arg3 - (Optional) Custom version for testrunner artifact (e.g., 1.0, 1.1-SNAPSHOT). Default is $TESTRUNNER_ARTIFACT_VERSION"
    exit
fi

if [[ ! $2 == "" ]]; then
    ARTIFACT_VERSION=$2
fi

if [[ ! $3 == "" ]]; then
    TESTRUNNER_ARTIFACT_VERSION=$3
fi

crnt=`pwd`
working_dir=`dirname $0`
project_path=$1

cd ${project_path}
project_path=`pwd`
cd - > /dev/null

cd ${working_dir}

javac PomFile.java
find ${project_path} -name pom.xml | grep -v "src/" | java PomFile ${ARTIFACT_ID} ${ARTIFACT_VERSION} ${CONFIGURATION_CLASS} ${TESTRUNNER_ARTIFACT_VERSION}
rm -f PomFile.class

cd ${crnt}
