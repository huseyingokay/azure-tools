slug=$1
modified_slug_sha_module=$2
sha=$(echo $modified_slug_sha_module | rev | cut -d'=' -f2 | cut -d'-' -f1 | rev)

echo "in clone-project.sh"
echo "slug: $slug"
echo "sha: $sha"
echo "projdir: $projdir"

cd ~/

if [[ ! -f "$AZ_BATCH_TASK_WORKING_DIR/input/"$modified_slug_sha_module".zip" ]]; then
    git clone https://github.com/$slug $slug
    cd $AZ_BATCH_TASK_WORKING_DIR/input/$slug
    git checkout $sha
    echo "SHA is $(git rev-parse HEAD)"
else
    cp $AZ_BATCH_TASK_WORKING_DIR/input/$modified_slug_sha_module.zip .
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
