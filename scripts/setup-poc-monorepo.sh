#!/usr/bin/env bash
# Δημιουργεί ένα τοπικό "remote" monorepo (bare repo) για το PoC.
# Χρήση: ./setup-poc-monorepo.sh <dir>   (default: ./poc)
set -euo pipefail

ROOT="$(realpath -m "${1:-./poc}")"
REMOTE="$ROOT/remote/monorepo.git"
SEED="$ROOT/seed"

rm -rf "$ROOT"
mkdir -p "$ROOT/remote"

git init --quiet --bare --initial-branch=main "$REMOTE"
# Επιτρέπει partial clone (--filter) από file:// — το GitHub/Azure DevOps/GitLab το υποστηρίζουν ήδη.
git -C "$REMOTE" config uploadpack.allowFilter true
git -C "$REMOTE" config uploadpack.allowAnySHA1InWant true

git init --quiet --initial-branch=main "$SEED"
cd "$SEED"
echo "# Monorepo PoC" > README.md
printf 'bin/\nobj/\n' > .gitignore
for p in projA projB projC; do
  mkdir -p "$p/src"
  echo "# $p" > "$p/README.md"
  echo "console.log('hello from $p');" > "$p/src/index.js"
done
git add -A
git -c user.name=seed -c user.email=seed@poc commit --quiet -m "Initial monorepo"
git remote add origin "file://$REMOTE"
git push --quiet -u origin main
cd - >/dev/null
rm -rf "$SEED"

echo "Remote monorepo: file://$REMOTE"
