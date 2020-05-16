#!/bin/bash
function success {
  echo -e "\033[1;32m$1\033[m" >&2
}

function info {
  echo -e "\033[1;36m$1\033[m" >&2
}

function error {
  echo -e "\033[1;31m$1\033[m" >&2
}


#change current directory to file path "semver-bump.txt"
cd ../

#If "semver-bump.txt" file does not exists, script will exit
FILE='semver-bump.txt'
if [ ! -f "$FILE" ]; then
    error "$FILE does NOT exist, hence exiting script"
    exit 1
fi

#If "semver-bump.txt" file has more than 1 line, script will exit
actual_lines=$(< "$FILE" wc -l | sed -e 's/^[ \t]*//')
if [ "$actual_lines" != 0 ]; then
    error "Multiple line exists in $FILE file,hence exiting script"
    exit 1
fi

#Fetching all git tags and filtering by latest one
git fetch -q --all --tags
tag=$(git describe --tags `git rev-list --tags --max-count=1`)
echo "Tag value $tag"
existing_tag=$tag


if [ -n "$tag" ]; then
    info "Git Tag exists for this repository ==> $tag"
else
    info "No Git Tag found for this repository"
    existing_tag="0.0.0"
fi

echo "Existing tag $tag"
#set the IFS value
OIFS=$IFS
IFS='.'
read -ra current_tag <<< "$existing_tag"

# #unset the IFS value
IFS=$OIFS



n=0
while read line || [ -n "$line" ] ; 
do  
version_details=$line
n=$((n+1))
done < $FILE


#set the IFS value
OIFS=$IFS
IFS='.'
read -ra ADDR <<< "$version_details"

# #unset the IFS value
IFS=$OIFS

echo "USER INPUT => $version_details"
if [ "${ADDR[0]}" = "B" ]; then
    upgrade="major"
elif [ "${ADDR[1]}" = "B" ]; then
    upgrade="minor"
elif [ "${ADDR[2]}" = "B" ]; then
    upgrade="patch"
fi

echo "Upgrading the $upgrade"

case $upgrade in

  "patch")
    new_tag=${current_tag[0]}.${current_tag[1]}.$((${current_tag[2]}+1)) 
    ;;

  "minor")
    new_tag=${current_tag[0]}.$((${current_tag[1]}+1)).0 
    ;;

  "major")
    new_tag=$((${current_tag[0]}+1)).0.0 
    ;;
esac

echo "New git tag version is $new_tag"

#get commit SHA for tagging
commit=$(git rev-parse HEAD)
info "commit message SHA => $commit"

# get repo name from git
remote=$(git config --get remote.origin.url)
repo=$(basename $remote .git)

#forming github repo URL
github_repo_url="https://api.github.com/repos/$REPO_OWNER/$repo/git/refs"
info "Github Repo URL => $github_repo_url"

#function which returns Data parameters
generate_post_data()
{
  cat <<EOF
{
  "ref": "refs/tags/$new_tag",
  "sha": "$commit"
}
EOF
}
info "Data Parameters => $(generate_post_data)"

#using CURL post the below request to add git tag to repository
curl_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -d "$(generate_post_data)" $github_repo_url)

info "Curl response => $curl_response"
if [ $? -eq 0 ]; then
  info "Curl request is success"
else
  info "Curl request Failed"
  exit 1
fi

ref=$(echo "$curl_response" | jq  -r '.ref')
info "Ref -> $ref"

#set the IFS value
OIFS=$IFS
IFS='/'
read -ra ref_split <<< "$ref"

#unset the IFS value
IFS=$OIFS
info "Array length ==> ${#ref_split[@]}"
for i in "${ref_split[@]}"
do
  if [ $i = $new_tag ]; then
    info "New Tag Version Committed successfully in remote"
    break
  fi
done

sha=$(echo "$curl_response" | jq -r '.object.sha')
info "sha -> $sha"

if [ $sha = $commit ]; then
  info "Commit SHA found successfully"
fi