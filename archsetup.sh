#!/usr/bin/bash
set -e

REPO="jwalk9000/archbase.btrfs"
BRANCH="public-testing"
LOCALREPO="/tmp/archbase"

# Install script dependencies
PKGDEPS=(
  "jq"
  "yq" 
  "fzf"
  "git"
)

pacman -Sy

echo "=> Installing script dependencies"
for PKG in "${PKGDEPS[@]}"; do
  if ! pacman -Qs "$PKG" > /dev/null ; then
    pacman -S --noconfirm "$PKG"
  fi
done

# Check if $LOCALREPO directory exists and is not empty
if [ -d $LOCALREPO ] && [ "$(ls -A $LOCALREPO)" ]; then
  echo "=> $LOCALREPO directory exists and is not empty. Proceeding to launch the main script."
else
  echo "=> $LOCALREPO directory does not exist or is empty. Cloning the repository."
  sleep 1.5
  git clone -b $BRANCH --single-branch https://github.com/$REPO.git $LOCALREPO
  cd $LOCALREPO
  chmod +x $LOCALREPO/*.sh
fi

# Ensure variables are exported for child scripts
export REPO
export BRANCH
export LOCALREPO

# Run the main script
exec $LOCALREPO/main.sh