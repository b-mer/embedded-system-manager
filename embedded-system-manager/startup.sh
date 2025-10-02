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

# Check if root
if [ $(id -u) -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

# Run in location of script
cd "$(dirname "$BASH_SOURCE")"   

# Update mirrors before running package installs
apt-get update

# Install if not exist function yoinked from stack exchange at https://codereview.stackexchange.com/questions/262937/installing-packages-if-they-dont-exist-in-bash
install_if_not_exist() {
  if dpkg -s "$1" &>/dev/null; then
    PKG_EXIST=$(dpkg -s "$1" | grep "install ok installed")
    if [[ -n "$PKG_EXIST" ]]; then
      return
    fi
  fi
  apt-get install "$1" -y
}

install_if_not_exist git

# Load config file (basically works as a bash script in itself)
source config

# Install Cage Window Manager if needed
if [ $run_in_cage -eq 1 ]; then
  echo "--- INSTALLING CAGE FOR KIOSK MODE ---"
  install_if_not_exist cage
  install_if_not_exist wlroots
fi

echo "--- CHECKING FOR UPGRADES ---"

# Run package updates
source upgrade_packages.sh

echo "--- UPDATING SCRIPTS FROM REPOSITORY ---"

# Grab scripts from repository
. install_repository.sh

# If run script flag set to true, start the repository program.
if [ $run_script -eq 1 ]; then
  echo "Startup complete, running script."
  cd $script_workspace
  
  # Check if we should run in Cage
  if [ $run_in_cage -eq 1 ]; then
    echo "Starting Cage Kiosk..."
    # Run the script within Cage
    # Cage will run on the first available TTY
    cage -- bash -c "$repo_run_command"
  else
    # Run normally without Cage
    eval "$repo_run_command"
  fi
  
  cd /opt/embedded-system-manager
else
  echo "Startup complete."
fi
