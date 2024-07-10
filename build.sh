#!/bin/bash

source functions.sh
source log-functions.sh

logInfoMessage "I'll create a Git tag for a branch if it doesn't exist."

if [ ! -d "/root/.ssh" ]; then
  mkdir -p /root/.ssh || { logErrorMessage "Failed to create /root/.ssh directory"; exit 1; }
  ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N "" > /dev/null 2>&1 || { logErrorMessage "Failed to generate SSH keys"; exit 1; }
fi

GIT_SSH_KEY=$(getEncryptedCredential "$GIT_REPO" "GIT_INFO.GIT_SSH_KEY")
echo "$GIT_SSH_KEY" > /root/.ssh/id_ed25519
chmod 600 /root/.ssh/id_ed25519

if [[ -z "$TAG_NAME" ]]; then
  logErrorMessage "Please provide the tag name."
  exit 1
fi

GIT_URL=$(getEncryptedCredential "$GIT_REPO" "GIT_INFO.GIT_URL")
GIT_BRANCH=$(getEncryptedCredential "$GIT_REPO" "GIT_INFO.GIT_BRANCH")
REPO_NAME=$(basename "$GIT_URL" ".git")

logInfoMessage "____ Start $GIT_URL ____"
logInfoMessage "Repository: $REPO_NAME"
logInfoMessage "Branch: $GIT_BRANCH"
logInfoMessage "Tag: $TAG_NAME"

cd /root || { logErrorMessage "Failed to change directory to /root"; exit 1; }
if [ ! -d "$REPO_NAME" ]; then
  GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git clone "$GIT_URL" > /dev/null 2>&1 || { logErrorMessage "Failed to clone repository $GIT_URL"; exit 1; }
fi

cd "$REPO_NAME" || { logErrorMessage "Failed to change directory to $REPO_NAME"; exit 1; }

git checkout "$GIT_BRANCH" > /dev/null 2>&1 || { logErrorMessage "Failed to checkout branch $GIT_BRANCH"; exit 1; }

if git tag -l "$TAG_NAME" | grep -q "$TAG_NAME"; then
  logErrorMessage "Git tag $TAG_NAME already exists in repository [$REPO_NAME]"
  exit 1
fi

git tag "$TAG_NAME" || { logErrorMessage "Failed to create Git tag $TAG_NAME"; exit 1; }

output=$(GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git push origin "$TAG_NAME" 2>&1)

if [ $? -eq 0 ]; then
  logInfoMessage "Git tag $TAG_NAME created and pushed successfully to repository [$REPO_NAME]"
else
  logErrorMessage "Failed to push Git tag $TAG_NAME: $output"
  exit 1
fi

logInfoMessage "$output"

logInfoMessage "Git tag $TAG_NAME created and pushed successfully to repository [$REPO_NAME]"
logInfoMessage "____ End $GIT_URL ____"
