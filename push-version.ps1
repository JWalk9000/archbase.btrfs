# push-version.ps1
$ErrorActionPreference = "Stop"
$LOG_FILE = ".push_history.log"
$scriptName = Split-Path -Leaf $MyInvocation.MyCommand.Path
$branch = git rev-parse --abbrev-ref HEAD
$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

function Get-LastTag($branch) {
    try { git describe --tags --abbrev=0 $branch } catch { "V1.0" }
}
function Get-CommitCount($branch) {
    $lastTag = Get-LastTag $branch
    git rev-list --count "$lastTag..HEAD"
}
function Get-MajorVersion($tag) {
    if ($tag -match "^V(\d+)") { return [int]$Matches[1] } else { return 1 }
}

# Check for uncommitted changes
$gitStatus = git status --porcelain
if ($gitStatus) {
    Write-Host "You have uncommitted changes."
    $commitNow = Read-Host "Would you like to commit them now? (y/n)"
    if ($commitNow -match "^[yY]") {
        git add .
        $msg = Read-Host "Enter a commit message"
        git commit -m "$msg"
    } else {
        Write-Host "Aborting push. Please commit or stash your changes first."
        exit 1
    }
}

# Prompt for a log message for this push
$pushMsg = Read-Host "Enter a brief log message for this push"

if ($branch -eq "dev") {
    $branchExists = git branch --list public-testing
    if (-not $branchExists) {
        git checkout -b public-testing
        git merge dev
        # Versioning logic (after merge)
        $lastTag = Get-LastTag "main"
        $commitCount = git rev-list --count "$lastTag..public-testing"
    } else {
        git checkout public-testing
        git merge dev
        # Versioning logic (after merge)
        $lastTag = Get-LastTag "public-testing"
        $commitCount = git rev-list --count "$lastTag..public-testing"
    }
    $version = "V1.$commitCount"
    # Update BRANCH variable in archsetup.sh to match the target branch
    (Get-Content archsetup.sh) -replace '^BRANCH=.*', 'BRANCH="public-testing"' | Set-Content archsetup.sh
    git add archsetup.sh
    "$date | dev → public-testing | $version | $pushMsg" | Add-Content $LOG_FILE
    git add $LOG_FILE
    git commit -m "update BRANCH variable"
    git tag -a $version -m "Public testing version $version"
    git push origin public-testing
    git push origin $version

    if (-not (Select-String -Path .gitignore -Pattern $scriptName -Quiet)) {
        Add-Content .gitignore $scriptName
    }
    if (-not (Select-String -Path .gitignore -Pattern "push-version.sh" -Quiet)) {
        Add-Content .gitignore "push-version.sh"
    }
    git add .gitignore
    git commit -m "Add push-version scripts to .gitignore for main branch hygiene"
    git push origin public-testing

    Write-Host "Pushed to public-testing as $version"
}
elseif ($branch -eq "public-testing") {
    git checkout main
    git merge public-testing
    # Versioning logic (after merge)
    $lastTag = Get-LastTag "main"
    $major = Get-MajorVersion $lastTag
    $nextMajor = $major + 1
    $version = "V$nextMajor.0"
    # Update BRANCH variable in archsetup.sh to match the target branch
    (Get-Content archsetup.sh) -replace '^BRANCH=.*', 'BRANCH="main"' | Set-Content archsetup.sh
    git add archsetup.sh
    "$date | public-testing → main | $version | $pushMsg" | Add-Content $LOG_FILE
    git add $LOG_FILE
    git commit -m "update BRANCH variable"
    git tag -a $version -m "Main release $version"
    git push origin main
    git push origin $version

    Write-Host "Pushed to main as $version"
}
else {
    Write-Host "Run this script from dev or public-testing branch only."
    exit 1
}

# Uncomment and adapt for hotfix/feature support in the future:
# elseif ($branch -like "hotfix/*") {
#   # Hotfix branch logic here
# }
# elseif ($branch -like "feature/*") {
#   # Feature branch logic here
# }

Write-Host "Push history:"
Get-Content $LOG_FILE | Select-Object -Last 10