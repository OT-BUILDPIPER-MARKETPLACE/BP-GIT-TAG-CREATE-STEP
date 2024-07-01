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
if [[ -z "$TAG_NAME" ]]; then
  logErrorMessage "Please provide the TAG_NAME."
  exit 1
fi

GIT_URL=$(getGitRepo)
GIT_BRANCH=$(getGitBranch)

if [[ -z "$GIT_URL" ]]; then
  logErrorMessage "Please provide the GIT_URL."
  exit 1
fi

if [[ -z "$GIT_BRANCH" ]]; then
  logErrorMessage "Please provide the GIT_BRANCH."
  exit 1
fi


# Extract the repository name
REPO_NAME=$(basename "$GIT_URL" ".git")

echo "____ Start $GIT_URL ____"

logInfoMessage "Received below arguments"
logInfoMessage "Repositry: $REPO_NAME"
logInfoMessage "Branch: $GIT_BRANCH"
logInfoMessage "Tag: $TAG_NAME"

# Clone the repository if it doesn't exist
if ! [[ -d "$REPO_NAME" ]]; then
  GIT_URL=${GIT_URL/https:\/\//}
  git clone https://${CREDENTIAL_USERNAME}:${CREDENTIAL_PASSWORD}@${GIT_URL} > /dev/null 2>&1
fi

# Navigate to the repository directory
cd $REPO_NAME

# # Check out the branch
  git checkout $GIT_BRANCH > /dev/null 2>&1

  if git tag -l "$TAG_NAME" | grep -q "$TAG_NAME"; then
    logErrorMessage "Git tag $TAG_NAME already exists in repository [$REPO_NAME]"
    exit 1
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
echo "____ End https://$GIT_URL ____"


