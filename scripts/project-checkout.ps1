<#
.SYNOPSIS
  Φέρνει ΕΝΑ project από το monorepo με sparse-checkout και δουλεύει σε project branch.

.EXAMPLE
  .\project-checkout.ps1 -Project projA -LocalPath C:\work\projA -RepoUrl https://github.com/org/monorepo.git
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Project,
    [Parameter(Mandatory)][string]$LocalPath,
    [string]$RepoUrl = $env:MONOREPO_URL,
    [string]$MainBranch = 'main',
    [string]$Branch
)
$ErrorActionPreference = 'Stop'

function Invoke-Git {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') απέτυχε (exit $LASTEXITCODE)" }
}
function Step($msg) { Write-Host ""; Write-Host "==> $msg" -ForegroundColor Cyan }

$Project = $Project.TrimEnd('/', '\')
if (-not $Branch) { $Branch = $Project }
if (-not $RepoUrl) { throw 'Δώσε -RepoUrl ή όρισε $env:MONOREPO_URL' }
if ($Project -notmatch '^[A-Za-z0-9._-]+$') { throw "Μη έγκυρο όνομα project: '$Project'" }

$LocalPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LocalPath)
if ((Test-Path $LocalPath) -and (Get-ChildItem -Force $LocalPath | Select-Object -First 1)) {
    throw "Το '$LocalPath' υπάρχει και δεν είναι άδειο."
}

# 1. Partial clone: κατεβαίνουν commits/trees, ΟΧΙ blobs. Τα blobs έρχονται on-demand μόνο για το project.
Step "Clone (partial, χωρίς checkout) από $RepoUrl"
Invoke-Git clone --quiet --filter=blob:none --no-checkout $RepoUrl $LocalPath
Push-Location $LocalPath
try {
    # 2. Υπάρχει το project στο main;
    $found = Invoke-Git ls-tree -d --name-only "origin/$MainBranch" -- $Project
    if (-not $found) {
        Write-Host "Το project '$Project' ΔΕΝ υπάρχει στο $MainBranch." -ForegroundColor Yellow
        $answer = Read-Host "Να δημιουργηθεί νέο project '$Project' στο $MainBranch; [y/N]"
        if ($answer -notmatch '^[YyΝν]$') {
            Pop-Location
            Remove-Item -Recurse -Force $LocalPath
            Write-Host 'Ακυρώθηκε.'
            exit 1
        }
        Step "Δημιουργία φακέλου '$Project' στο $MainBranch"
        Invoke-Git sparse-checkout set --cone $Project
        Invoke-Git switch --quiet $MainBranch
        New-Item -ItemType Directory -Force $Project | Out-Null
        Set-Content -Path (Join-Path $Project 'README.md') -Value "# $Project"
        Invoke-Git add --sparse $Project
        Invoke-Git commit --quiet -m "Create project $Project"
        Invoke-Git push --quiet origin $MainBranch
    }

    # 3. Sparse-checkout μόνο του project (cone mode)
    Step "Sparse-checkout: $Project"
    Invoke-Git sparse-checkout set --cone $Project

    # 4. Project branch
    & git show-ref --verify --quiet "refs/remotes/origin/$Branch"
    if ($LASTEXITCODE -eq 0) {
        Step "Το branch '$Branch' υπάρχει ήδη στο remote — checkout"
        Invoke-Git switch --quiet $Branch
    } else {
        Step "Δημιουργία branch '$Branch' από origin/$MainBranch και push"
        Invoke-Git switch --quiet -c $Branch "origin/$MainBranch"
        Invoke-Git push --quiet -u origin $Branch
    }

    # 5. Local guard: απορρίπτει commits που αγγίζουν αρχεία εκτός του project.
    #    Τα git hooks τρέχουν με sh (και στα Windows, μέσω Git for Windows) -> LF, χωρίς BOM.
    $hook = @(
        '#!/bin/sh'
        "outside=`$(git diff --cached --name-only | grep -v '^$Project/')"
        'if [ -n "$outside" ]; then'
        "  echo `"pre-commit: επιτρέπονται αλλαγές μόνο μέσα στο '$Project/'. Εκτός:`" >&2"
        '  echo "$outside" >&2'
        '  exit 1'
        'fi'
    ) -join "`n"
    $hookPath = Join-Path $LocalPath '.git/hooks/pre-commit'
    [IO.File]::WriteAllText($hookPath, "$hook`n", [Text.UTF8Encoding]::new($false))
    if ($IsLinux -or $IsMacOS) { & chmod +x $hookPath }

    Step 'Έτοιμο'
    Write-Host "Path   : $LocalPath"
    Write-Host "Branch : $(Invoke-Git branch --show-current) -> $(Invoke-Git rev-parse --abbrev-ref '@{u}')"
    Write-Host "Sparse : $((Invoke-Git sparse-checkout list) -join ' ')"
    Write-Host 'Αρχεία στο working tree:'
    Get-ChildItem -Recurse -File -Force |
        Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
        ForEach-Object { '  ' + $_.FullName.Substring($LocalPath.Length + 1) } |
        Sort-Object
} finally {
    if ((Get-Location).Path -eq $LocalPath) { Pop-Location }
}
