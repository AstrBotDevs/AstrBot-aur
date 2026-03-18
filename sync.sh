#!/bin/bash

set -euo pipefail

BRANCH=$(git symbolic-ref --short HEAD)

get_remote_url() {
    git remote get-url "$1" 2>/dev/null || true
}

AUR_REMOTE=""
GITHUB_REMOTE=""

for remote in $(git remote); do
    url=$(get_remote_url "$remote")
    case "$url" in
        *aur.archlinux.org*)
            AUR_REMOTE="$remote"
            ;;
        *github.com*)
            GITHUB_REMOTE="$remote"
            ;;
    esac
done

if [[ -z "$AUR_REMOTE" ]]; then
    echo "Adding AUR remote..."
    git remote add aur https://aur.archlinux.org/astrbot-git.git
    AUR_REMOTE="aur"
fi

echo "Fetching latest commits from AUR remote: $AUR_REMOTE"
git fetch --prune "$AUR_REMOTE"

echo "Fast-forwarding local branch '$BRANCH' to AUR latest commit..."
git pull --ff-only "$AUR_REMOTE" "$BRANCH"

if [[ -n "$GITHUB_REMOTE" ]]; then
    echo "Pushing latest commit to GitHub remote: $GITHUB_REMOTE"
    git push "$GITHUB_REMOTE" "$BRANCH"
else
    echo "No GitHub remote found, skipping mirror push."
fi

echo "Sync complete!"
