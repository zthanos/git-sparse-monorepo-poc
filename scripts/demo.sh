#!/usr/bin/env bash
# Τρέχει όλο το σενάριο του PoC από την αρχή.
set -uo pipefail
cd "$(dirname "$0")/.."
export GIT_AUTHOR_NAME=dev GIT_AUTHOR_EMAIL=dev@poc GIT_COMMITTER_NAME=dev GIT_COMMITTER_EMAIL=dev@poc
S="$PWD/scripts"
hr() { echo; echo "##################### $*"; }

hr "0. Στήσιμο remote monorepo (projA, projB, projC)"
"$S/setup-poc-monorepo.sh" ./poc
export MONOREPO_URL="file://$PWD/poc/remote/monorepo.git"

hr "1. projA υπάρχει -> sparse + νέο branch projA"
"$S/project-checkout.sh" projA ./poc/work/projA

hr "2. projX δεν υπάρχει, απάντηση 'n' -> ακύρωση"
echo n | "$S/project-checkout.sh" projX ./poc/work/projX; echo "exit=$?"

hr "3. projX δεν υπάρχει, απάντηση 'y' -> δημιουργία στο main + branch projX"
echo y | "$S/project-checkout.sh" projX ./poc/work/projX

hr "4. Αλλαγή στο projA, commit, push"
cd poc/work/projA
echo "console.log('feature 1');" >> projA/src/index.js
git commit -qam "projA: feature 1" && git push -q && git log --oneline -3

hr "5. Προσπάθεια αλλαγής αρχείου εκτός project"
echo "hack" >> README.md
git commit -qam "touch root README" ; echo "exit=$?"
git checkout -q -- README.md
echo "--- και αρχείο άλλου project (εκτός sparse cone):"
mkdir -p projB && echo hack > projB/README.md
git add projB/README.md; echo "exit=$?"
rm -rf projB

hr "6. 'PR' projA -> main: τι θα μεταφερθεί; (git diff main...projA)"
git fetch -q
git diff --stat origin/main...origin/projA
cd ../../..

hr "7. Δεύτερος developer: projA υπάρχει ΚΑΙ branch υπάρχει -> clone του branch"
"$S/project-checkout.sh" projA ./poc/work/projA-dev2
git -C poc/work/projA-dev2 log --oneline -2

hr "8. Merge του PR (σε full clone, όπως θα έκανε το GitHub/Azure DevOps)"
git clone -q "$MONOREPO_URL" poc/work/full
cd poc/work/full
git merge -q --no-ff origin/projA -m "Merge PR projA" 
git push -q origin main
git show --stat --format='%s' HEAD
echo "--- main μετά το merge:"
git ls-tree -r --name-only origin/main | sed 's/^/  /'

hr "9. Μέγεθος: blobs που κατέβηκαν στο sparse clone vs full"
cd ../projA
echo "sparse projA: $(git rev-list --objects --all --missing=print | grep -c '^?') blobs λείπουν (δεν κατέβηκαν)"
