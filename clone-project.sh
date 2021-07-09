
slug=$1
sha=$2
cd ~/

if [[ ! -f "/input/$slug.zip" ]]; then
    echo "================Cloning the project: $(date)"
    cd input
    git clone https://github.com/$slug $slug
    zip $slug
    cp $slug.zip $AZ_BATCH_TASK_WORKING_DIR
    unzip $slug.zip
    cd $slug
    git checkout $sha
    echo "SHA is $(git rev-parse HEAD)"
else
    cp /input/$slug.zip .
    unzip $slug.zip
    cd $slug
    git checkout $sha
    echo "$slug already exists"
    echo "SHA is $(git rev-parse HEAD)"
fi
if [[ "$(git rev-parse HEAD)" == "$sha" ]]; then
    exit 0
else
    exit 1
fi
