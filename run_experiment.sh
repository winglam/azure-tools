# Usage: bash run_experiment.sh /mnt/batch/tasks/workitems/SUA_tmp_r2_8M7d9h7m23s/job-1/raft-issre-mods /mnt/batch/tasks/workitems/SUA_tmp_r2_8M7d9h7m23s/job-1 compiled-projects-w-deps/ba2 testTimes-file.csv 100 |& tee all-results.log
# bash run_experiment.sh /mnt/batch/tasks/workitems/SUA_tmp_r2_8M7d9h7m23s/job-1/raft-issre-mods /mnt/batch/tasks/workitems/SUA_tmp_r2_8M7d9h7m23s/job-1 compiled-projects-w-deps/test tmp-test.csv 3 |& tee all-results.log

dir=$(pwd)
dir_path=$1
AZ_BATCH_TASK_WORKING_DIR=$2
output_dir=$3
inputfile=$4 # from http://mir.cs.illinois.edu/winglam/personal/testTimes-file.csv
rounds=$5
starttime=$(date +%s)

echo "================ Test starttime: $(date)"
echo "================ script vers: $(git rev-parse HEAD)"
for project in $(tac $inputfile | rev | cut -d, -f1 | rev);
do
    line=$(cat ${dir_path}/$project)
    slug=$(echo ${line} | cut -d',' -f1 | rev | cut -d'/' -f1-2 | rev)
    sha=$(echo ${line} | cut -d',' -f2)
    module=$(echo ${line} | cut -d',' -f3 | sed 's?\./??g' | sed 's/\//+/g')
    modified_slug_module="$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')-${sha:0:7}=${module}"

    just_name="$modified_slug_module"
    cd $dir
    bash run_surefire_azure.sh ${dir_path}/$project $rounds compiled-projects-w-deps reversealphabetical $AZ_BATCH_TASK_WORKING_DIR |& tee ${just_name}_output.log
    cd $AZ_BATCH_TASK_WORKING_DIR

    RESULTSDIR=${modified_slug_module}_output/
    mv $dir/${just_name}_output.log ${RESULTSDIR}
    zip -rq ${just_name}.zip ${RESULTSDIR}
    mkdir -p ${output_dir}-${starttime}
    mv ${just_name}.zip ${output_dir}-${starttime}
done
echo "================ Test endtime: $(date)"
