slug=$1
modified_slug_sha_module=$2
input_container=$3
sha=$(echo $modified_slug_sha_module | rev | cut -d'=' -f2 | cut -d'-' -f1 | rev)

echo "in clone-project.sh"
echo "slug: $slug"
echo "sha: $sha"
echo "modified_slug_sha_module: $modified_slug_sha_module"

cd ~/


if [[ -f "$AZ_BATCH_TASK_WORKING_DIR/$slug" ]]; then
    echo "The project is already in the working directory"
    cd $AZ_BATCH_TASK_WORKING_DIR/$slug
    git checkout $sha
    echo "SHA is $(git rev-parse HEAD)"
elif [[ ! -f "$AZ_BATCH_TASK_WORKING_DIR/$input_container/$modified_slug_sha_module.zip" ]]; then
    git clone https://github.com/$slug $slug
    cd $AZ_BATCH_TASK_WORKING_DIR/$slug
    git checkout $sha
    echo "SHA is $(git rev-parse HEAD)"
else
    echo "$slug already exists in the container"
    cp $AZ_BATCH_TASK_WORKING_DIR/$input_container/$modified_slug_sha_module.zip .
    unzip $modified_slug_sha_module.zip
    cd $AZ_BATCH_TASK_WORKING_DIR/$slug
    git checkout $sha
    echo "SHA is $(git rev-parse HEAD)"
fi
if [[ "$(git rev-parse HEAD)" == "$sha" ]]; then
    exit 0
else
    exit 1
fi