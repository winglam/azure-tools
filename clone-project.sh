
slug=$1
sha=$2

echo "================Cloning the project"
cd ~/
git clone https://github.com/$slug $slug
cd $slug
git checkout $sha 
