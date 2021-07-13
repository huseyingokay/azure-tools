slug=$1
sha=$2
projdir=$slug | cut -d'-' -f1 | tr . /
projectname=${slug%/*}


echo "in clone-project.sh"
echo "slug: $slug"
echo "sha: $sha"
echo "projectname: $projectname"
echo "projdir: $projdir"
echo "modifiedslug_with_sha: $modifiedslug_with_sha"

cd ~/

if [[ ! -f "$AZ_BATCH_TASK_WORKING_DIR/input/"$slug".zip" ]]; then
    git clone https://github.com/$projdir $projdir
    cd $AZ_BATCH_TASK_WORKING_DIR/$input_container/$projdir
    git checkout $sha
    echo "SHA is $(git rev-parse HEAD)"
else
    cp $AZ_BATCH_TASK_WORKING_DIR/input/$slug.zip .
    unzip $slug.zip
    cd $projdir
    git checkout $sha
    echo "$projdir already exists"
    echo "SHA is $(git rev-parse HEAD)"
fi
if [[ "$(git rev-parse HEAD)" == "$sha" ]]; then
    exit 0
else
    exit 1
fi
