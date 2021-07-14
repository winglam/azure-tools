slug=$1
modified_slug_sha_module=$2
input_container=$3
sha=$(echo $modified_slug_sha_module | rev | cut -d'=' -f2 | cut -d'-' -f1 | rev)

cd ~/$AZ_BATCH_TASK_WORKING_DIR

if [[ -d $slug ]]; then
    echo "The project is already in the working directory"
    cd $slug
    git checkout $sha
    echo "SHA is $(git rev-parse HEAD)"
elif [[ ! -f "$input_container/$modified_slug_sha_module.zip" ]]; then
    git clone https://github.com/$slug $slug
    cd $slug
    git checkout $sha
    echo "SHA is $(git rev-parse HEAD)"
else
    echo "$slug already exists in the container"
    cp $input_container/$modified_slug_sha_module.zip .
    unzip -q $modified_slug_sha_module.zip
    cd $slug
    echo "SHA is $(git rev-parse HEAD)"
fi
if [[ "$(git rev-parse HEAD)" == "$sha" ]]; then
    exit 0
else
    exit 1
fi
