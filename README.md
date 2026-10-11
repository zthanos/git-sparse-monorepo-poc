# git sparse monorepo PoC

Proof of concept: κάθε project ενός monorepo δουλεύεται σε δικό του branch, με `git sparse-checkout` και partial clone. Το PR προς το `main` μεταφέρει μόνο τις αλλαγές του φακέλου του project.

## Scripts

| Αρχείο | Περιγραφή |
|---|---|
| [scripts/project-checkout.sh](scripts/project-checkout.sh) | `./project-checkout.sh <project> <local_path> [repo_url]` |
| [scripts/project-checkout.ps1](scripts/project-checkout.ps1) | `.\project-checkout.ps1 -Project <p> -LocalPath <path> [-RepoUrl <url>] [-MainBranch main] [-Branch <name>]` |
| [scripts/setup-poc-monorepo.sh](scripts/setup-poc-monorepo.sh) | Στήνει τοπικό bare "remote" monorepo (projA, projB, projC) στο `./poc` |
| [scripts/demo.sh](scripts/demo.sh) | Τρέχει όλα τα σενάρια από την αρχή |

Το `repo_url` μπορεί να δοθεί και μέσω της μεταβλητής `MONOREPO_URL`.

## Ροή

1. Partial clone (`--filter=blob:none --no-checkout`): κατεβαίνει μόνο το ιστορικό, χωρίς περιεχόμενο αρχείων.
2. Αν ο φάκελος του project δεν υπάρχει στο `main`, ζητάει επιβεβαίωση και τον δημιουργεί με commit και push στο `main`.
3. `git sparse-checkout set --cone <project>`.
4. Αν υπάρχει το remote branch `<project>`, κάνει checkout σε αυτό. Αλλιώς το δημιουργεί από το `main` και κάνει push.
5. Εγκαθιστά `pre-commit` hook που απορρίπτει αλλαγές εκτός του `<project>/`.

## Περιορισμοί

- Το branch είναι snapshot ολόκληρου του repo. Το sparse περιορίζει το working tree και τις αλλαγές, όχι το περιεχόμενο του branch. Το diff και το PR περιέχουν μόνο τον φάκελο του project.
- Το cone mode φέρνει πάντα και τα αρχεία της ρίζας. Το hook εμποδίζει την αλλαγή τους.
- Το hook είναι τοπικό. Για πραγματική προστασία χρειάζεται έλεγχος στο server (CI check στο diff του PR ή CODEOWNERS ανά φάκελο).
- Αν το `main` είναι protected, η δημιουργία νέου project με απευθείας push θα απορριφθεί.
- Το `project-checkout.ps1` δεν έχει δοκιμαστεί σε PowerShell.

## Δοκιμή

```bash
./scripts/demo.sh
```
