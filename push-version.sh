#!/usr/bin/env bash
set -e

LOG_FILE=".push_history.log"
SCRIPT_NAME="$(basename "$0")"
BRANCH=$(git rev-parse --abbrev-ref HEAD)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Helper: get last tag on a branch
get_last_tag() {
  git describe --tags --abbrev=0 "$1" 2>/dev/null || echo "V1.0"
}

# Helper: get commit count since last tag
get_commit_count() {
  local base_branch=$1
  local last_tag
  last_tag=$(get_last_tag "$base_branch")
  git rev-list --count "${last_tag}..HEAD"
}

# Helper: get major version from tag
get_major_version() {
  echo "$1" | grep -oP '^V\K[0-9]+'
}

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
  echo "You have uncommitted changes."
  read -p "Would you like to commit them now? (y/n): " commit_now
  if [[ "$commit_now" =~ ^[yY]$ ]]; then
    git add .
    read -p "Enter a commit message: " msg
    git commit -m "$msg"
  else
    echo "Aborting push. Please commit or stash your changes first."
    exit 1
  fi
fi

# Prompt for a log message for this push
read -p "Enter a brief log message for this push: " push_msg

# Main logic
if [[ "$BRANCH" == "dev" ]]; then
  git checkout public-testing 2>/dev/null || git checkout -b public-testing
  git merge dev

  # Update BRANCH variable in archsetup.sh to match the target branch
  sed -i 's/^BRANCH=.*/BRANCH="public-testing"/' archsetup.sh
  git add archsetup.sh
  git commit -m "update BRANCH variable"

  last_tag=$(get_last_tag public-testing)
  commit_count=$(get_commit_count public-testing)
  version="V1.$commit_count"
  git tag -a "$version" -m "Public testing version $version"
  git push origin public-testing
  git push origin "$version"

  # Add both script versions to .gitignore if not already present
  if ! grep -q "$SCRIPT_NAME" .gitignore; then
    echo "$SCRIPT_NAME" >> .gitignore
  fi
  if ! grep -q "push-version.ps1" .gitignore; then
    echo "push-version.ps1" >> .gitignore
  fi
  if ! grep -q "push-version.sh" .gitignore; then
    echo "push-version.sh" >> .gitignore
  fi
  git add .gitignore
  git commit -m "Add push-version scripts to .gitignore for main branch hygiene"
  git push origin public-testing

  echo "$DATE | dev → public-testing | $version | $push_msg" >> "$LOG_FILE"
  echo "Pushed to public-testing as $version"

elif [[ "$BRANCH" == "public-testing" ]]; then
  git checkout main
  git merge public-testing

  # Update BRANCH variable in archsetup.sh to match the target branch
  sed -i 's/^BRANCH=.*/BRANCH="main"/' archsetup.sh
  git add archsetup.sh
  git commit -m "update BRANCH variable"

  last_tag=$(get_last_tag main)
  major=$(get_major_version "$last_tag")
  next_major=$((major + 1))
  version="V${next_major}.0"
  git tag -a "$version" -m "Main release $version"
  git push origin main
  git push origin "$version"

  echo "$DATE | public-testing → main | $version | $push_msg" >> "$LOG_FILE"
  echo "Pushed to main as $version"

# Uncomment and adapt for hotfix/feature support in the future:
# elif [[ "$BRANCH" == hotfix/* ]]; then
#   # Hotfix branch logic here
#   :
# elif [[ "$BRANCH" == feature/* ]]; then
#   # Feature branch logic here
#   :

else
  echo "Run this script from dev or public-testing branch only."
  exit 1
fi

echo "Push history:"
tail -n 10 "$LOG_FILE"
