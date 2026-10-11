#!/usr/bin/env bash
# Φέρνει ΕΝΑ project από το monorepo με sparse-checkout και δουλεύει σε project branch.
#
# Χρήση: ./project-checkout.sh <project> <local_path> [repo_url]
#   repo_url  : default από $MONOREPO_URL
#   $MAIN_BRANCH : default "main"
#   $PROJECT_BRANCH : default = <project>
set -euo pipefail

PROJECT="${1:?Χρήση: $0 <project> <local_path> [repo_url]}"
LOCAL_PATH="${2:?Χρήση: $0 <project> <local_path> [repo_url]}"
REPO_URL="${3:-${MONOREPO_URL:?Δώσε repo_url ή όρισε MONOREPO_URL}}"
MAIN="${MAIN_BRANCH:-main}"
BRANCH="${PROJECT_BRANCH:-$PROJECT}"

PROJECT="${PROJECT%/}"
if [[ ! "$PROJECT" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Μη έγκυρο όνομα project: '$PROJECT'" >&2; exit 1
fi
if [[ -e "$LOCAL_PATH" && -n "$(ls -A "$LOCAL_PATH" 2>/dev/null)" ]]; then
  echo "Το '$LOCAL_PATH' υπάρχει και δεν είναι άδειο." >&2; exit 1
fi

step() { echo; echo "==> $*"; }

# 1. Partial clone: κατεβαίνουν commits/trees, ΟΧΙ blobs. Τα blobs έρχονται on-demand μόνο για το project.
step "Clone (partial, χωρίς checkout) από $REPO_URL"
git clone --quiet --filter=blob:none --no-checkout "$REPO_URL" "$LOCAL_PATH"
cd "$LOCAL_PATH"

# 2. Υπάρχει το project στο main;
if [[ -z "$(git ls-tree -d --name-only "origin/$MAIN" -- "$PROJECT")" ]]; then
  echo "Το project '$PROJECT' ΔΕΝ υπάρχει στο $MAIN."
  read -r -p "Να δημιουργηθεί νέο project '$PROJECT' στο $MAIN; [y/N] " answer
  if [[ ! "$answer" =~ ^[YyΝν]$ ]]; then
    cd - >/dev/null; rm -rf "$LOCAL_PATH"
    echo "Ακυρώθηκε."; exit 1
  fi
  step "Δημιουργία φακέλου '$PROJECT' στο $MAIN"
  git sparse-checkout set --cone "$PROJECT"
  git switch --quiet "$MAIN"
  mkdir -p "$PROJECT"
  echo "# $PROJECT" > "$PROJECT/README.md"
  git add --sparse "$PROJECT"
  git commit --quiet -m "Create project $PROJECT"
  git push --quiet origin "$MAIN"
fi

# 3. Sparse-checkout μόνο του project (cone mode)
step "Sparse-checkout: $PROJECT"
git sparse-checkout set --cone "$PROJECT"

# 4. Project branch
if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
  step "Το branch '$BRANCH' υπάρχει ήδη στο remote — checkout"
  git switch --quiet "$BRANCH"
else
  step "Δημιουργία branch '$BRANCH' από origin/$MAIN και push"
  git switch --quiet -c "$BRANCH" "origin/$MAIN"
  git push --quiet -u origin "$BRANCH"
fi

# 5. Local guard: απορρίπτει commits που αγγίζουν αρχεία εκτός του project.
cat > .git/hooks/pre-commit <<HOOK
#!/bin/sh
outside=\$(git diff --cached --name-only | grep -v '^$PROJECT/')
if [ -n "\$outside" ]; then
  echo "pre-commit: επιτρέπονται αλλαγές μόνο μέσα στο '$PROJECT/'. Εκτός:" >&2
  echo "\$outside" >&2
  exit 1
fi
HOOK
chmod +x .git/hooks/pre-commit

step "Έτοιμο"
echo "Path   : $(pwd)"
echo "Branch : $(git branch --show-current) -> $(git rev-parse --abbrev-ref '@{u}')"
echo "Sparse : $(git sparse-checkout list | tr '\n' ' ')"
echo "Αρχεία στο working tree:"
find . -path ./.git -prune -o -type f -print | sort | sed 's/^/  /'
