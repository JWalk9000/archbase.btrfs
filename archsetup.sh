#!/usr/bin/bash
set -e

REPO="jwalk9000/archbase.btrfs"

BRANCH="dev"

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

# Check if /tmp/archbase directory exists and is not empty
if [ -d /tmp/archbase ] && [ "$(ls -A /tmp/archbase)" ]; then
  echo "=> /tmp/archbase directory exists and is not empty. Proceeding to launch the main script."
else
  echo "=> /tmp/archbase directory does not exist or is empty. Cloning the repository."
  git clone -b $BRANCH --single-branch https://github.com/$REPO.git /tmp/archbase
  cd /tmp/archbase
  chmod +x /tmp/archbase/*.sh
fi

# Run the main script
exec /tmp/archbase/main.sh