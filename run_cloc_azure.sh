#!/bin/bash

echo "epoch: 1590617255"

if [[ $1 == "" ]]; then
    echo "arg1 - Path to CSV file with project,sha,test"
    exit
fi

RESULTSDIR=~/output/
mkdir -p ${RESULTSDIR}

cd ~/
projfile=$1
rounds=$2
input_container=$3
line=$(head -n 1 $projfile)
echo "================Starting experiment for input: $line"
slugFull=$(echo ${line} | cut -d',' -f1)
slug=$(echo ${line} | cut -d',' -f1 | rev | cut -d'/' -f1-2 | rev)
sha=$(echo ${line} | cut -d',' -f2)
modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"
module='.'
modified_module=$(echo ${module} | sed 's?\./??g' | sed 's/\//+/g')
modified_slug_module="${modifiedslug_with_sha}=${modified_module}"

MVNOPTIONS="-Ddependency-check.skip=true -Dmaven.repo.local=$AZ_BATCH_TASK_WORKING_DIR/dependencies_$modified_slug_module -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip"

echo "================Clonning the project"

bash $dir/clone-project.sh "$slug" "$modified_slug_module" "$input_container"
ret=${PIPESTATUS[0]}
if [[ $ret != 0 ]]; then
    if [[ $ret == 2 ]]; then
        echo "$line,$modified_slug_module,cannot_clone" >> $AZ_BATCH_TASK_WORKING_DIR/$input_container/results/"$modified_slug_module-results".csv
        echo "Couldn't download the project. Actual: $ret"
        exit 1
    elif [[ $ret == 1 ]]; then
        cd ~/
        rm -rf ${slug%/*}
        wget "https://github.com/$slug/archive/$sha".zip
        ret=${PIPESTATUS[0]}
        if [[ $ret != 0 ]]; then
            echo "$line,$modified_slug_module,cannot_checkout_or_wget" >> $AZ_BATCH_TASK_WORKING_DIR/$input_container/results/"$modified_slug_module-results".csv
            echo "Compilation failed. Actual: $ret"
            exit 1
        else
            echo "git checkout failed but wget successfully downloaded the project and sha, proceeding to the rest of this script"
            mkdir -p $slug
            unzip -q $sha -d $slug
            cd $slug/*
            to_be_deleted=${PWD##*/}  
            mv * ../
            cd ../
            rm -rf $to_be_deleted  
        fi
    else
        echo "Compilation failed. Actual: $ret"
        exit 1   
    fi  
fi

cd ~/$slug

if [[ -z $module ]]; then
    echo "================ Missing module. Exiting now!"
    exit 1
else
    echo "Module passed in from csv."
fi
echo "Location of module: $module"

# echo "================Installing the project"
bash $dir/install-project.sh "$slug" "$MVNOPTIONS" "$USER" "$module" "$sha" "$dir" "$fullTestName" "${RESULTSDIR}" "$input_container"
ret=${PIPESTATUS[0]}
mv mvn-install.log ${RESULTSDIR}
if [[ $ret != 0 ]]; then
    # mvn install does not compile - return 0
    echo "Compilation failed. Actual: $ret"
    exit 1
fi

ret=${PIPESTATUS[0]}
mv mvn-install.log ${RESULTSDIR}
if [[ $ret != 0 ]]; then
    # mvn install does not compile - return 0
    echo "Compilation failed. Actual: $ret"
    exit 1
fi

# Timeout for each module's test is 3hr
mvn test ${MVNOPTIONS} -Dsurefire.timeout=10800 -X |& tee mvn-test-all.log

ret=${PIPESTATUS[0]}
mv mvn-test-all.log ${RESULTSDIR}

echo "================Parsing test list"
pip install BeautifulSoup4
pip install lxml

wget http://mir.cs.illinois.edu/winglam/personal/parse_surefire_report-a281abbecbac34c5de4d68e87d921ddd8f49c8c6.py -O ${RESULTSDIR}/parse_surefire_report.py
echo "" > all-test-results.csv
for f in $(find -name "TEST*.xml"); do
    python ${RESULTSDIR}/parse_surefire_report.py $f -1  >> all-test-results.csv
done
cat all-test-results.csv | sort -u | awk NF > ${RESULTSDIR}/all-test-results.csv


rm -rf ${RESULTSDIR}/summary.csv
rm -rf ${RESULTSDIR}/loc.csv
for g in $(find -name pom.xml); do
    moduledir=$(echo $g | rev | cut -d'/' -f2- | rev)
    echo "================Checking module: $moduledir"

    cd $moduledir/
    mkdir -p ${RESULTSDIR}/$moduledir
    rm -rf module-test-results.csv
    for f in $(find -name "TEST*.xml"); do
	python ${RESULTSDIR}/parse_surefire_report.py $f -1  >> module-test-results.csv
    done
    cat module-test-results.csv | sort -u | awk NF > ${RESULTSDIR}/$moduledir/module-test-results.csv

    cloc . --csv --quiet | grep -v -e '^$' | grep -v files,language,blank,comment,code | grep -v Counting: | sed -e "s|^|all,$moduledir,|" >> ${RESULTSDIR}/loc.csv
    cloc . --csv --quiet --match-d='/src/main/java/' | grep -v -e '^$' | grep -v files,language,blank,comment,code | grep -v Counting: | sed -e "s|^|cut,$moduledir,|" >> ${RESULTSDIR}/loc.csv
    cloc . --csv --quiet --match-d='/src/test/java/' | grep -v -e '^$' | grep -v files,language,blank,comment,code | grep -v Counting: | sed -e "s|^|test,$moduledir,|" >> ${RESULTSDIR}/loc.csv

    allCode=$(grep "^all,\\$moduledir," ${RESULTSDIR}/loc.csv | grep ,Java, | cut -d, -f7 | sort -u)
    cutCode=$(grep "^cut,\\$moduledir," ${RESULTSDIR}/loc.csv | grep ,Java, | cut -d, -f7 | sort -u)
    testCode=$(grep "^test,\\$moduledir," ${RESULTSDIR}/loc.csv | grep ,Java, | cut -d, -f7 | sort -u)
    testCount=$(wc -l ${RESULTSDIR}/$moduledir/module-test-results.csv | cut -d' ' -f1)
    echo $slugFull,$sha,$moduledir,$allCode,$cutCode,$testCode,$testCount >> ${RESULTSDIR}/summary.csv
    
    cd -
done

hasall=$(grep all,., ${RESULTSDIR}/loc.csv)
if [[ -z $hasall ]]; then
    cloc . --csv --quiet | grep -v -e '^$' | grep -v files,language,blank,comment,code | grep -v Counting: | sed -e "s|^|all,.,|" >> ${RESULTSDIR}/loc.csv
    cloc . --csv --quiet --match-d='/src/main/java/' | grep -v -e '^$' | grep -v files,language,blank,comment,code | grep -v Counting: | sed -e "s|^|cut,.,|" >> ${RESULTSDIR}/loc.csv
    cloc . --csv --quiet --match-d='/src/test/java/' | grep -v -e '^$' | grep -v files,language,blank,comment,code | grep -v Counting: | sed -e "s|^|test,.,|" >> ${RESULTSDIR}/loc.csv
fi

# Save all Test XMLs
mkdir -p ${RESULTSDIR}/xmls/
for f in $(find -name "TEST*.xml"); do mv $f ${RESULTSDIR}/xmls/; done


cd ${RESULTSDIR}/

allCode=$(grep "^all,\.," loc.csv | grep ,Java, | cut -d, -f7 | sort -u)
cutCode=$(grep "^cut,\.," loc.csv | grep ,Java, | cut -d, -f7 | sort -u)
testCode=$(grep "^test,\.," loc.csv | grep ,Java, | cut -d, -f7 | sort -u)
testCount=$(wc -l all-test-results.csv | cut -d' ' -f1)
echo $slugFull,$sha,.,$allCode,$cutCode,$testCode,$testCount >> summary.csv

sort -u summary.csv > t
rm summary.csv
mv t summary.csv
