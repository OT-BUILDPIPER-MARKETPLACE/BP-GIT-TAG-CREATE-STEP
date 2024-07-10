#!/bin/bash

# Import required functions
source functions.sh
source log-functions.sh
source str-functions.sh
source file-functions.sh
source aws-functions.sh

logInfoMessage "I'll create a Git tag for a branch if it doesn't exist."
sleep $SLEEP_DURATION

ENCRYPTED_CREDENTIAL_USERNAME=$(getEncryptedCredential "$GIT_REPO" "GIT_INFO.GIT_USERNAME")
CREDENTIAL_USERNAME=$(getDecryptedCredential "$FERNET_KEY" "$ENCRYPTED_CREDENTIAL_USERNAME")


ENCRYPTED_CREDENTIAL_PASSWORD=$(getEncryptedCredential "$GIT_REPO" "GIT_INFO.GIT_PASSWORD")
CREDENTIAL_PASSWORD=$(getDecryptedCredential "$FERNET_KEY" "$ENCRYPTED_CREDENTIAL_PASSWORD")


# Check if the branch name and tag name are provided
if [[ -z "$TAG_NAME" ]]; then
  logErrorMessage "Please provide the tag name."
  exit 1
fi

GIT_URL=$(getEncryptedCredential "$GIT_REPO" "GIT_INFO.GIT_URL")
GIT_BRANCH=$(getEncryptedCredential "$GIT_REPO" "GIT_INFO.GIT_BRANCH")

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

    git push origin "$TAG_NAME" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        logInfoMessage "Git tag $TAG_NAME pushed successfully to repository [$REPO_NAME]"
    else
        git push origin "$TAG_NAME"
        logErrorMessage "Git tag $TAG_NAME failed pushed to repository [$REPO_NAME]"
    fi
  fi

# Navigate back to the parent directory
cd ..
echo "____ End https://$GIT_URL ____"


