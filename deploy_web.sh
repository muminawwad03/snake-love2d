#!/usr/bin/env bash
# Builds the web version and publishes it as a new commit on the gh-pages
# branch, which GitHub Pages serves at
#   https://muminawwad03.github.io/snake-love2d/
set -euo pipefail
cd "$(dirname "$0")"

./build_web.sh

pages=build/pages
rm -rf build
git worktree prune

# Check out gh-pages in a separate folder (create it the first time)
if git ls-remote --exit-code --heads origin gh-pages >/dev/null; then
    git fetch -q origin gh-pages
    git worktree add -q -B gh-pages "$pages" origin/gh-pages
else
    git worktree add -q --orphan -b gh-pages "$pages"
fi

# Replace its contents with the fresh build
find "$pages" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -R dist/. "$pages/"

git -C "$pages" add -A
if git -C "$pages" diff --cached --quiet; then
    echo "No changes to deploy."
else
    git -C "$pages" commit -q -m "Deploy web build from $(git rev-parse --short HEAD)"
    git -C "$pages" push -q origin gh-pages
    echo "Deployed. Live in about a minute at https://muminawwad03.github.io/snake-love2d/"
fi

git worktree remove --force "$pages"
