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
[ "$GIT_STATUS" = "" ] || fail "ERROR: Cannot publish release with uncommitted changes:\n$GIT_STATUS"

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
        if ! git checkout "$BRANCH" 2>/dev/null; then
            BRANCH_FROM="${PREFIX}.0"
            echo "Branch $BRANCH does not exist. Creating it off of tag $BRANCH_FROM..."
            # Make sure <major>.<minor>.0 tag is on branch latest
            if [ "$(git rev-parse "$BRANCH_FROM")" != "$(git merge-base origin/latest "$BRANCH_FROM")" ]; then
                fail "ERROR: Tag $BRANCH_FROM is not on branch latest"
            fi

            # Checkout tag <major>.<minor>.0 and create branch
            # v<major>.<minor>-dev off of it
            git checkout --detach "$BRANCH_FROM"
            git checkout -b "$BRANCH"
            # Push branch unless DRY_RUN=true
            if [ "$DRY_RUN" != true ]; then
                git push --set-upstream origin "$BRANCH"
            fi
        fi
        ;;
esac

# Download latest OpenAPI spec and CLI doc, and update if necessary
gh release download "$TAG" -p openapi.yaml -p nuodb-cp.adoc --clobber
git add openapi.yaml nuodb-cp.adoc
git commit --allow-empty -m "Create release $TAG"

# Force update and push tag unless DRY_RUN=true
if [ "$DRY_RUN" != true ]; then
    git tag "$TAG" --force
    git push --tags --force
    git push
fi

# Checkout original branch or commit
git checkout "$ORIG_REF"
