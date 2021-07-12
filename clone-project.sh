slug=$1
sha=$2
input_container=$3
projectname=${slug%/*}
cd ~/

if [[ ! -f "$AZ_BATCH_TASK_WORKING_DIR/$input_container/$projectname.zip" ]]; then
    echo "================Cloning the project: $(date)"
    cd $input_container
    git clone https://github.com/$slug $slug
    cd $AZ_BATCH_TASK_WORKING_DIR/$input_container/$slug
    git checkout $sha
    echo "SHA is $(git rev-parse HEAD)"
else
    cp $AZ_BATCH_TASK_WORKING_DIR/$input_container/$projectname.zip .
    unzip $projectname.zip
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
