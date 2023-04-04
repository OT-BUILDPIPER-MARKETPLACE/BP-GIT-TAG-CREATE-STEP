#!/bin/bash

# Import required functions
source functions.sh
source log-functions.sh
source str-functions.sh
source file-functions.sh
source aws-functions.sh

logInfoMessage "I'll create a Git tag for a branch if it doesn't exist."
sleep $SLEEP_DURATION

# Check if the branch name and tag name are provided
if [[ -z "$BRANCH_NAME" || -z "$TAG_NAME" ]]; then
  logErrorMessage "Please provide the branch name and tag name."
  exit 1
fi

IFS=',' read -ra REPOSITORIES <<< "$REPOSITORIES"
# Iterate over each repository
for REPOSITORY in "${REPOSITORIES[@]}"; do
  # Extract the repository name
  REPO_NAME=$(basename "$REPOSITORY" ".git")

  echo "____ Start https://$REPO_NAME ____"

  logInfoMessage "Received below arguments"
  logInfoMessage "Repositry: $REPO_NAME"
  logInfoMessage "Branch: $BRANCH_NAME"
  logInfoMessage "Tag: $TAG_NAME"

  # Clone the repository if it doesn't exist
  if ! [[ -d "$REPO_NAME" ]]; then
    git clone "$REPOSITORY" > /dev/null 2>&1
  fi

  # Navigate to the repository directory
  cd $REPO_NAME

  # # Check out the branch
   git checkout $BRANCH_NAME > /dev/null 2>&1

   if git tag -l "$TAG_NAME" | grep -q "$TAG_NAME"; then
     logInfoMessage "Git tag $TAG_NAME already exists in repository [$REPO_NAME]"
   else
     # Create the Git tag
     git tag $TAG_NAME 
     logInfoMessage "Git tag $TAG_NAME created successfully in repository [$REPO_NAME]"

     # Push the tag to the remote repository
     git push origin "$TAG_NAME" > /dev/null 2>&1

     logInfoMessage "Git tag $TAG_NAME pushed successfully to repository [$REPO_NAME]"
   fi

  # Navigate back to the parent directory
  cd ..
  echo "____ End https://$REPO_NAME ____"

done
