slug=$1
sha=$2
projectname=${slug%/*}

modifiedslug=$(echo ${slug} | sed 's;/;.;' | tr '[:upper:]' '[:lower:]')
short_sha=${sha:0:7}
modifiedslug_with_sha="${modifiedslug}-${short_sha}"
modified_module=$(echo ${module} | cut -d'.' -f2- | cut -c 2- | sed 's/\//+/g')

echo "in clone-project.sh"
echo "slug: $slug"
echo "sha: $sha"
echo "projectname: $projectname"

cd ~/

if [[ ! -f "$AZ_BATCH_TASK_WORKING_DIR/input/"$modifiedslug_with_sha=$modified_module".zip" ]]; then
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
