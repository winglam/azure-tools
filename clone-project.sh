
slug=$1
sha=$2
cd ~/

if [[ ! -d "$slug" ]]; then
    echo "================Cloning the project: $(date)"
    git clone https://github.com/$slug $slug
    cd $slug
    git checkout $sha
    echo "SHA is $(git rev-parse HEAD)"
else
    cd $slug
    echo "$slug already cloned"
    echo "SHA is $(git rev-parse HEAD)"
fi
if [[ "$(git rev-parse HEAD)" == "$sha" ]]; then
    exit 0
else
    exit 1
fi
