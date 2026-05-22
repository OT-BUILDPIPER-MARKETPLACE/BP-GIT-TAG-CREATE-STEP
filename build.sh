#!/bin/bash

# ---------------------------------------------------------------
# NOTE: ACTIVITY_SUB_TASK_CODE is managed by the BuildPiper
#       environment. Do NOT override it here to ensure events
#       appear correctly in the UI.
# ---------------------------------------------------------------

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

if [[ "$DEBUG_MODE" == "true" ]]; then
    set -x
fi

# ---------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------
WORKSPACE="${WORKSPACE:-/bp/workspace}"
RESULT="${DEPLOY_TAG%-*}"
CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"

# ---------------------------------------------------------------
# 1. Initialization
# ---------------------------------------------------------------
logInfoMessage "> Starting step: git_tag_create"
logInfoMessage "> Codebase location: ${CODEBASE_LOCATION}"

add_event "INITIALIZATION" "Successful" \
    "Git Tag Create step initialized" \
    "Codebase: ${CODEBASE_DIR} | Workspace: ${WORKSPACE}"

if [ -n "$SLEEP_DURATION" ] && [ "$SLEEP_DURATION" -gt 0 ] 2>/dev/null; then
    logInfoMessage "> Sleeping for ${SLEEP_DURATION} second(s)..."
    sleep "$SLEEP_DURATION"
fi

# ---------------------------------------------------------------
# 2. Input Validation
# ---------------------------------------------------------------
logInfoMessage "> Validating inputs..."

if [[ -z "$WORKSPACE" || -z "$CODEBASE_DIR" ]]; then
    logErrorMessage "> WORKSPACE or CODEBASE_DIR is not set — cannot proceed"
    add_event "INPUT_VALIDATION" "Failed" \
        "Required environment variables are missing" \
        "WORKSPACE: ${WORKSPACE:-<unset>} | CODEBASE_DIR: ${CODEBASE_DIR:-<unset>}"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

add_event "INPUT_VALIDATION" "Successful" \
    "Required environment variables validated" \
    "WORKSPACE: ${WORKSPACE} | CODEBASE_DIR: ${CODEBASE_DIR}"

# ---------------------------------------------------------------
# 3. Workspace Navigation
# ---------------------------------------------------------------
logInfoMessage "> Navigating to codebase directory..."

cd "$CODEBASE_LOCATION" || {
    logErrorMessage "> Failed to navigate to codebase directory: ${CODEBASE_LOCATION}"
    add_event "WORKSPACE_NAVIGATION" "Failed" \
        "Cannot change to codebase directory" \
        "Path: ${CODEBASE_LOCATION} | Verify WORKSPACE and CODEBASE_DIR"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
}

logInfoMessage "> Successfully navigated to: ${CODEBASE_LOCATION}"
add_event "WORKSPACE_NAVIGATION" "Successful" \
    "Navigated to codebase directory" \
    "Path: ${CODEBASE_LOCATION}"

# ---------------------------------------------------------------
# Git Context Helper
# ---------------------------------------------------------------
getGitContext() {
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        logErrorMessage "> Not inside a Git repository"
        return 1
    fi

    GIT_URL=$(git config --get remote.origin.url || true)
    if [[ -z "$GIT_URL" ]]; then
        logErrorMessage "> Remote origin URL not found"
        return 1
    fi

    REPO_NAME=$(basename "$GIT_URL" .git)

    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    if [[ -z "$GIT_BRANCH" || "$GIT_BRANCH" == "HEAD" ]]; then
        GIT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
    fi

    if [[ -z "$GIT_BRANCH" ]]; then
        logErrorMessage "> Could not determine Git branch"
        return 1
    fi

    if [[ "$GIT_URL" =~ ^git@ ]]; then
        logInfoMessage "> SSH-based Git URL detected — no credentials required"
        export GIT_URL REPO_NAME GIT_BRANCH
        return 0
    fi

    if [[ "$GIT_URL" =~ ^https://([^:/]+):([^@]+)@ ]]; then
        CREDENTIAL_USERNAME="${BASH_REMATCH[1]}"
        CREDENTIAL_PASSWORD="${BASH_REMATCH[2]}"
        export CREDENTIAL_USERNAME CREDENTIAL_PASSWORD
        logInfoMessage "> HTTPS credentials detected (masked)"
    else
        logInfoMessage "> HTTPS URL without embedded credentials — using credential helper or pre-auth repo"
    fi

    export GIT_URL REPO_NAME GIT_BRANCH
    return 0
}

# ---------------------------------------------------------------
# 4. Git Context Detection
# ---------------------------------------------------------------
logInfoMessage "> Detecting Git repository context..."

if ! getGitContext; then
    add_event "GIT_CONTEXT_DETECTION" "Failed" \
        "Failed to fetch Git repository information" \
        "Verify the codebase is a valid Git repo with a configured remote origin"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

logInfoMessage "> Repository: ${REPO_NAME}"
logInfoMessage "> Branch    : ${GIT_BRANCH}"

add_event "GIT_CONTEXT_DETECTION" "Successful" \
    "Git repository context detected" \
    "Repo: ${REPO_NAME} | Branch: ${GIT_BRANCH}"

# ---------------------------------------------------------------
# 5. Tag Name Resolution
# ---------------------------------------------------------------
logInfoMessage "> Resolving tag name..."

if [[ -n "$TAG_NAME" ]]; then
    logInfoMessage "> Using user-provided TAG_NAME: ${TAG_NAME}"
elif [[ -n "$RESULT" ]]; then
    TAG_NAME="${GIT_BRANCH}-${RESULT}"
    logInfoMessage "> TAG_NAME derived from branch + build number: ${TAG_NAME}"
else
    logErrorMessage "> Neither TAG_NAME nor DEPLOY_TAG is provided — cannot create tag"
    add_event "TAG_RESOLUTION" "Failed" \
        "Tag name could not be resolved" \
        "Set TAG_NAME or DEPLOY_TAG in pipeline configuration"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

add_event "TAG_RESOLUTION" "Successful" \
    "Tag name resolved successfully" \
    "Tag: ${TAG_NAME} | Branch: ${GIT_BRANCH}"

# ---------------------------------------------------------------
# 6. Execution Summary
# ---------------------------------------------------------------
echo ""
echo "> Git Tag Create Execution Summary"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Parameter" "Value"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Repository" "${REPO_NAME}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Branch" "${GIT_BRANCH}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Tag" "${TAG_NAME}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Codebase" "${CODEBASE_DIR}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
echo ""

# ---------------------------------------------------------------
# 7. Git Branch Checkout
# ---------------------------------------------------------------
logInfoMessage "> Checking out branch: ${GIT_BRANCH}..."

if ! git checkout "$GIT_BRANCH" > /dev/null 2>&1; then
    logErrorMessage "> Failed to checkout branch: ${GIT_BRANCH}"
    add_event "GIT_CHECKOUT" "Failed" \
        "Failed to checkout branch" \
        "Branch: ${GIT_BRANCH} | Repo: ${REPO_NAME}"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

logInfoMessage "> Branch checked out successfully: ${GIT_BRANCH}"
add_event "GIT_CHECKOUT" "Successful" \
    "Branch checked out successfully" \
    "Branch: ${GIT_BRANCH} | Repo: ${REPO_NAME}"

# ---------------------------------------------------------------
# 8. Git Tag Creation & Push
# ---------------------------------------------------------------
logInfoMessage "> Checking if tag already exists: ${TAG_NAME}..."

if git tag -l "$TAG_NAME" | grep -q "$TAG_NAME"; then
    logErrorMessage "> Git tag '${TAG_NAME}' already exists in repository: ${REPO_NAME}"
    add_event "GIT_TAG_CREATE" "Failed" \
        "Git tag already exists — cannot create duplicate" \
        "Tag: ${TAG_NAME} | Repo: ${REPO_NAME}"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

logInfoMessage "> Creating tag: ${TAG_NAME}..."
git tag "$TAG_NAME"

logInfoMessage "> Pushing tag to origin: ${TAG_NAME}..."
if ! git push origin "$TAG_NAME" > /dev/null 2>&1; then
    logErrorMessage "> Failed to push tag '${TAG_NAME}' to origin"
    add_event "GIT_TAG_CREATE" "Failed" \
        "Tag created locally but push to origin failed" \
        "Tag: ${TAG_NAME} | Repo: ${REPO_NAME} | Check remote permissions"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

logInfoMessage "> Tag '${TAG_NAME}' created and pushed successfully to: ${REPO_NAME}"
add_event "GIT_TAG_CREATE" "Successful" \
    "Git tag created and pushed to remote" \
    "Tag: ${TAG_NAME} | Branch: ${GIT_BRANCH} | Repo: ${REPO_NAME}"

# ---------------------------------------------------------------
# 9. Final Status
# ---------------------------------------------------------------
logInfoMessage "> Git Tag Create step completed successfully"
saveTaskStatus 0 "${ACTIVITY_SUB_TASK_CODE}"
exit 0
