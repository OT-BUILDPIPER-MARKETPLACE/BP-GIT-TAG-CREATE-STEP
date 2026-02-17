#!/bin/bash

if [[ "$DEBUG_MODE" == "true" ]]; then
    set -x
else
    set +x
fi

DEPLOY_TAG=29-2026-02-17-183508
RESULT=${DEPLOY_TAG%-*}

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh


if [[ -z "$WORKSPACE" || -z "$CODEBASE_DIR" ]]; then
    logErrorMessage "WORKSPACE or CODEBASE_DIR environment variables not set!"
    exit 1
fi

CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"

logInfoMessage "Processing at path: [$CODEBASE_LOCATION]"
sleep "$SLEEP_DURATION"

cd "$CODEBASE_LOCATION" || {
    logErrorMessage "Cannot cd into $CODEBASE_LOCATION";
    exit 1;
}

getGitContext() {
    logInfoMessage "Detecting Git repository context..."

    # -------------------------------
    # Ensure we are inside a git repo
    # -------------------------------
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        logErrorMessage "Not inside a Git repository"
        return 1
    fi

    # -------------------------------
    # Remote URL
    # -------------------------------
    GIT_URL=$(git config --get remote.origin.url || true)

    if [[ -z "$GIT_URL" ]]; then
        logErrorMessage "Remote origin URL not found"
        return 1
    fi

    logInfoMessage "Remote origin URL detected (masked)"

    # -------------------------------
    # Repo name
    # -------------------------------
    REPO_NAME=$(basename "$GIT_URL" .git)

    # -------------------------------
    # Branch name
    # -------------------------------
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)

    if [[ -z "$GIT_BRANCH" || "$GIT_BRANCH" == "HEAD" ]]; then
        GIT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
    fi

    if [[ -z "$GIT_BRANCH" ]]; then
        logErrorMessage "Could not determine Git branch"
        return 1
    fi

    # -------------------------------
    # Credentials (optional)
    # -------------------------------
    if [[ "$GIT_URL" =~ ^git@ ]]; then
        logInfoMessage "SSH-based Git URL detected. No credentials required."
        return 0
    fi

    if [[ "$GIT_URL" =~ ^https://([^:/]+):([^@]+)@ ]]; then
        CREDENTIAL_USERNAME="${BASH_REMATCH[1]}"
        CREDENTIAL_PASSWORD="${BASH_REMATCH[2]}"

        export CREDENTIAL_USERNAME
        export CREDENTIAL_PASSWORD

        logInfoMessage "Embedded HTTPS credentials detected (masked)"
    else
        logInfoMessage "HTTPS Git URL without embedded credentials detected"
        logInfoMessage "Assuming git credential helper or pre-authenticated repo"
    fi

    export GIT_URL
    export REPO_NAME
    export GIT_BRANCH

    return 0
}

# -------------------------------
# Fetch Git credentials
# -------------------------------
getGitContext
# -------------------------------
# Validate input
# -------------------------------
if [[ -n "$TAG_NAME" ]]; then
    logInfoMessage "Using user-provided TAG_NAME: $TAG_NAME"

elif [[ -n "$RESULT" ]]; then
    TAG_NAME="$GIT_BRANCH-$RESULT"
    logInfoMessage "TAG_NAME not provided, using BRANCH + BUILD NO + Date: $TAG_NAME"

else
    logErrorMessage "Error: Neither TAG_NAME nor DEPLOY_TAG is provided."
    exit 1
fi

logInfoMessage "Repository: $REPO_NAME"
logInfoMessage "Branch: $GIT_BRANCH"
logInfoMessage "Tag: $TAG_NAME"

# Checkout branch
# -------------------------------
if ! git checkout "$GIT_BRANCH" > /dev/null 2>&1; then
    logErrorMessage "Failed to checkout branch $GIT_BRANCH"
    exit 1
fi

# -------------------------------
# Create tag if it doesn't exist
# -------------------------------
if git tag -l "$TAG_NAME" | grep -q "$TAG_NAME"; then
    logErrorMessage "Git tag $TAG_NAME already exists in repository [$REPO_NAME]"
    exit 1
else
    git tag "$TAG_NAME"
    logInfoMessage "Git tag $TAG_NAME created successfully in repository [$REPO_NAME]"

    if ! git push origin "$TAG_NAME" > /dev/null 2>&1; then
        logErrorMessage "Failed to push tag $TAG_NAME to origin"
        exit 1
    fi
    logInfoMessage "Git tag $TAG_NAME pushed successfully to repository [$REPO_NAME]"
fi


