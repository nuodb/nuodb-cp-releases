#!/bin/sh

fail() {
    printf "$1\n" >&2
    exit 1
}

set -e

: ${TAG:?"Must specify release tag"}

# Make sure there are no uncommitted changes
GIT_STATUS="$(git status --porcelain)"
[ "$GIT_STATUS" = "" ] || fail "Cannot publish release with uncommitted changes:\n$GIT_STATUS"

# Save current branch
MAIN_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

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
            git checkout "${PREFIX}.0"
            git checkout -b "$BRANCH"
            git push --set-upstream origin "$BRANCH"
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

# Checkout original branch
git checkout "$MAIN_BRANCH"
