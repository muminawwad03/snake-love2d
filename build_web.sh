#!/usr/bin/env bash
# Builds the browser version of the game into ./dist using love.js.
# Needs Node. deploy_web.sh calls this and publishes dist/ to GitHub Pages.
#   ./build_web.sh && python3 -m http.server -d dist 8000
set -euo pipefail
cd "$(dirname "$0")"

rm -rf dist build
mkdir -p build

# Package only the game's runtime files into a .love (a zip)
zip -9 -q -r build/snake.love . \
    -x "dist/*" "build/*" "web/*" ".git/*" \
       "tests.lua" "README.md" "build_web.sh" "deploy_web.sh" "highscore.txt" ".*"

# -c = compatibility mode: no SharedArrayBuffer, so it works on GitHub
# Pages, which can't send the special headers the threaded build needs
npx --yes love.js@11.4.1 -c -t "Snake" build/snake.love dist

# Replace the default love.js page with our themed one
cp web/index.html dist/index.html
rm -rf dist/theme build
touch dist/.nojekyll
echo "Web build ready in dist/"
