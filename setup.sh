#!/bin/bash

#    Embedded System Manager
#    Copyright (C) 2025  Briar Merrett
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Check if root, if not, run with sudo.
if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

# Check if whiptail is installed.
if ! command -v whiptail &> /dev/null; then
  echo "Error: whiptail is not installed." >&2
  exit 1
fi

# Check if git is installed.
if ! command -v git &> /dev/null; then
  echo "Error: git is not installed." >&2
  exit 1
fi

cd "$(dirname "$BASH_SOURCE")"   

# Run configuration setup.
chmod +x embedded-system-manager/config_setup.sh
source embedded-system-manager/config_setup.sh

echo "Copying script directory to /opt directory..."

# Install embedded-system-manager
yes | cp -rf embedded-system-manager /opt

# Get rid of windows /r newlines to prevent bugs
sed -i 's/\r$//' /opt/embedded-system-manager/*

echo "Making scripts executable..."

# Set all scripts to root executable permissions
chmod 744 /opt/embedded-system-manager/*

echo "Copying systemd embedded-system-deployer.service file to /etc/systemd/system directory..."

# Installing embedded-system-deployer systemd service
yes | cp -f embedded-system-deployer.service /etc/systemd/system

echo "Setting appropiate permissions for embedded-system-deployer.service..."

# Setting systemd service to appropiate permissions
chmod 664 /etc/systemd/system/embedded-system-deployer.service

echo "Creating new command 'edman'..."

# Installing edman command
cp edman /usr/bin

# Settng edman command to appropiate permissions
chmod 755 /usr/bin/edman


echo "Cloning repository into $DEPLOY_LOCATION..."

# Clone repository to deploy location
script_workspace=$DEPLOY_LOCATION
repository_url=$GIT_REPO
repository_branch=$GIT_REPO_BRANCH
full_repo_refresh=1
source /opt/embedded-system-manager/install_repository.sh

echo "Enabling and starting embedded-system-deployer.service..."
# Enabling and starting embedded-system-deployer systemd service
systemctl enable embedded-system-deployer.service
systemctl start embedded-system-deployer.service

echo "Setup complete." 
