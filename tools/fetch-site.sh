#!/usr/bin/env bash
# Pulls the problem bank and route data from the practice site's repository
# at the commit named in SITE_COMMIT, and writes bank/problems.json and
# bank/route.json, which the app reads. bank/ is not committed: run this
# after cloning and again whenever SITE_COMMIT changes.
#
#   tools/fetch-site.sh
#
# Needs bash, curl, tar and node.
set -euo pipefail
cd "$(dirname "$0")/.."

repo="txmmytwostraps/gdscript-practice"
commit="$(tr -d '[:space:]' < SITE_COMMIT)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "site repo at $commit"
curl -sSL -o "$work/site.tar.gz" "https://github.com/$repo/archive/$commit.tar.gz"
tar -xzf "$work/site.tar.gz" -C "$work"

rm -rf bank
node tools/build-bank.mjs "$work/gdscript-practice-$commit" bank
echo "$commit" > bank/COMMIT
