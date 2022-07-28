#!/bin/bash

set -e
set -x

if [ -z "$INPUT_SOURCE_FOLDERS" ]
then
  echo "Source folders must be defined"
  return -1
fi

if [ "${#INPUT_SOURCE_FOLDERS[@]}" != "${#INPUT_DESTINATION_FOLDER[@]}" ]
then
  echo "Invalid length for source and destination folder"
  exit 1
fi

if [ $INPUT_DESTINATION_HEAD_BRANCH == "main" ] || [ $INPUT_DESTINATION_HEAD_BRANCH == "master"]
then
  echo "Destination head branch cannot be 'main' nor 'master'"
  return -1
fi

if [ -z "$INPUT_PULL_REQUEST_REVIEWERS" ]
then
  PULL_REQUEST_REVIEWERS=$INPUT_PULL_REQUEST_REVIEWERS
else
  PULL_REQUEST_REVIEWERS='-r '$INPUT_PULL_REQUEST_REVIEWERS
fi

CLONE_DIR=$(mktemp -d)

echo "Setting git variables"
export GITHUB_TOKEN=$API_TOKEN_GITHUB
git config --global user.email "$INPUT_USER_EMAIL"
git config --global user.name "$INPUT_USER_NAME"
rand=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 4 ;)

echo "Cloning destination git repository"
git clone "https://$API_TOKEN_GITHUB@github.com/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"

echo "Copying contents to git repo"


for i in "${!INPUT_SOURCE_FOLDERS[@]}"; do
    mkdir -p $CLONE_DIR/${INPUT_DESTINATION_FOLDER[i]}/
    cp -r ${INPUT_SOURCE_FOLDERS[i]} "$CLONE_DIR/${INPUT_DESTINATION_FOLDER[i]}"
    echo "${INPUT_SOURCE_FOLDERS[i]} ${INPUT_DESTINATION_FOLDER[i]}"
done
cd "$CLONE_DIR"
git checkout -b "$INPUT_DESTINATION_HEAD_BRANCH-$rand"

echo "Adding git commit"
git add .
if (git status | grep -q "Changes to be committed")
then
  git commit --message "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
  echo "Pushing git commit"
  git push -u origin HEAD:"$INPUT_DESTINATION_HEAD_BRANCH-$rand"
  echo "Creating a pull request"
  gh pr create -t "$INPUT_DESTINATION_HEAD_BRANCH-$rand" \
               -b "$INPUT_DESTINATION_HEAD_BRANCH-$rand" \
               -B $INPUT_DESTINATION_BASE_BRANCH \
               -H "$INPUT_DESTINATION_HEAD_BRANCH-$rand" \
                  $PULL_REQUEST_REVIEWERS
else
  echo "No changes detected"
fi
