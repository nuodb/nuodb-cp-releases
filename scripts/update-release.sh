#!/bin/sh

fail() {
    printf "$1\n" >&2
    exit 1
}

set -e

: ${TAG:?"Must specify release tag"}

# Change to root directory
cd "$(dirname "$0")/.."

# Make sure there are no uncommitted changes
GIT_STATUS="$(git status --porcelain)"
[ "$GIT_STATUS" = "" ] || fail "Cannot publish release with uncommitted changes:\n$GIT_STATUS"

# Save current branch or commit
ORIG_REF="$(git rev-parse --abbrev-ref HEAD)"
if [ "$ORIG_REF" = HEAD ]; then
    # In detached head, so get commit SHA
    ORIG_REF="$(git rev-parse HEAD)"
fi

# Checkout correct branch for release
case "$TAG" in
    (*.0)
        # Branch latest tracks <major>.<minor>.0 releases
        git checkout latest
        ;;
    (*)
        # Branch v<major>.<minor>-dev tracks patch releases
        PREFIX="${TAG%.*}"
        BRANCH="${PREFIX}-dev"
        if ! git checkout "$BRANCH"; then
            # Branch does not exist. Create it off of <major>.<minor>.0.
            git checkout "${PREFIX}.0"
            git checkout -b "$BRANCH"
            if [ "$DRY_RUN" != true ]; then
                git push --set-upstream origin "$BRANCH"
            fi
        fi
        ;;
esac

# Download latest openapi.yaml and update if necessary
gh release download "$TAG" -p openapi.yaml --clobber
git add openapi.yaml
git commit --allow-empty -m "Create release $TAG"

# Force update and push tag unless DRY_RUN=true
if [ "$DRY_RUN" != true ]; then
    git tag "$TAG" --force
    git push --tags --force
    git push
fi

# Checkout original branch or commit
git checkout "$ORIG_REF"
