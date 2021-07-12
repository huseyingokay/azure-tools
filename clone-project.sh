slug=$1
sha=$2
projectname=${slug%/*}

echo "in clone-project.sh"
echo "slug: $slug"
echo "sha: $sha"
echo "projectname: $projectname"

cd ~/

if [[ ! -f "$AZ_BATCH_TASK_WORKING_DIR/input/$projectname.zip" ]]; then
    git clone https://github.com/$slug $slug
    cd $AZ_BATCH_TASK_WORKING_DIR/$input_container/$slug
    git checkout $sha
    echo "SHA is $(git rev-parse HEAD)"
else
    cp $AZ_BATCH_TASK_WORKING_DIR/input/$projectname.zip .
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
