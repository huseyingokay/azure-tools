
slug=$1
sha=$2
projectname=${slug%/*}
cd ~/

if [[ ! -f "$AZ_BATCH_TASK_WORKING_DIR/input/$projectname.zip" ]]; then
    echo "================Cloning the project: $(date)"
    cd input
    git clone https://github.com/$slug $slug
    cd $AZ_BATCH_TASK_WORKING_DIR/input
    zip -r $projectname.zip $projectname
    rm -r $projectname
    cp $projectname.zip $AZ_BATCH_TASK_WORKING_DIR
    cd $AZ_BATCH_TASK_WORKING_DIR
    unzip $projectname
    cd $slug
    git checkout $sha
    echo "SHA is $(git rev-parse HEAD)"
else
    cp /input/$slug.zip .
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
