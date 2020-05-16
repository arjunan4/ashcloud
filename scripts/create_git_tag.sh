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

# get latest tag
git fetch -q --all --tags
tag=$(git describe --tags `git rev-list --tags --max-count=1`)

if [ -n "$tag" ]; then
    info "Git Tag exists for this repository ==> $tag"
else
    info "No Git Tag found for this repository"
    tag="0.0.0"
fi

#set the IFS value
OIFS=$IFS
IFS='.'
read -ra ADDR <<< "$tag"

info "Existing Tag version details => $tag" 
info "Git Tag is splitted by . and array length is ==> ${#ADDR[@]}"

if [ ${#ADDR[@]} = 3 ]; then
  current_major_ver=${ADDR[0]}
  current_minor_ver=${ADDR[1]}
  current_patch_ver=${ADDR[2]}
  if [[ ${ADDR[0]} == *"v"* ]]; then
    current_major_ver=${ADDR[0]#"v"}
  fi
  info "Major => $current_major_ver ; Minor => $current_minor_ver ; Patch => $current_patch_ver"
  if [ $current_minor_ver = 9 ]; then
    new_minor_ver="0"
    new_patch_ver="0"
    let "new_major_ver=$current_major_ver+1"
  else
    let "new_minor_ver=$current_minor_ver + 1"
    new_patch_ver="0"
    new_major_ver="$current_major_ver" 
  fi
  new_tag_version="$new_major_ver.$new_minor_ver.$new_patch_ver"
  info "New Tag version details => $new_tag_version" 
  info "Major => $new_major_ver ; Minor => $new_minor_ver ; Patch => $new_patch_ver"
else
  info "Git tag format is NOT as expcted,hence exiting version script"
  exit 1
fi

#unset the IFS value
IFS=$OIFS
new_tag_version="$new_major_ver.$new_minor_ver.$new_patch_ver"
info "bumping Git Tag to => ${new_tag_version} new version"

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
  "ref": "refs/tags/$new_tag_version",
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
  if [ $i = $new_tag_version ]; then
    info "New Tag Version Committed successfully in remote"
    break
  fi
done

sha=$(echo "$curl_response" | jq -r '.object.sha')
info "sha -> $sha"

if [ $sha = $commit ]; then
  info "Commit SHA found successfully"
fi