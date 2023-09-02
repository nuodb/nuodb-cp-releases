#!/bin/sh

fail() {
    printf "$1\n" >&2
    exit 1
}

set -e

: ${TAG:?"Must specify release tag"}

# Make sure there are no uncommitted changes
GIT_STATUS="$(git status --porcelain)"
[ "$GIT_STATUS" = "" ] || fail "Cannot publish charts with uncommitted changes:\n$GIT_STATUS"

# Change to root directory
cd "$(dirname "$0")/.."

# Download Helm charts for release
rm -rf assets/
gh release download "$TAG" -p '*.tgz' -D "assets/$TAG"
[ "assets/$TAG/*.tgz" != "" ] || fail "No Helm charts downloaded for release $TAG"

# Checkout gh-pages and fast forward to origin
git checkout gh-pages
git merge --ff-only origin/gh-pages

# Update index with new Helm charts
: ${GH_RELEASES_URL:="https://github.com/nuodb/nuodb-cp-releases/releases/download"}
helm repo index assets --merge charts/index.yaml --url "$GH_RELEASES_URL"
mv assets/index.yaml charts/
git add charts/index.yaml
git commit -m "Add $TAG charts to index"

# Push change if PUSH_UPDATE=true
if [ "$PUSH_UPDATE" = true ]; then
    git push
fi
