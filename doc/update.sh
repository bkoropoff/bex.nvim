#!/bin/sh
set -e
remote=`git config --get remote.origin.url`
cd doc/html
[ -d .git ] && rm -rf .git
git init
git remote add origin "$remote"
touch .nojekyll
git add * .nojekyll
git commit -m "Doc update"
git push --force origin HEAD:gh-pages
