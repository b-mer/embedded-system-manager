#!/bin/bash
set -euo pipefail

#    Embedded System Manager
#    Copyright (C) 2026  Briar Merrett
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
  exec sudo -S "$BASH_SOURCE" "$@"
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

# Save the original directory where the script was run
SCRIPT_DIR="$(cd "$(dirname "$BASH_SOURCE")" && pwd)"

# Verify script directory is accessible
if [ ! -d "$SCRIPT_DIR" ]; then
  echo "ERROR: Script directory is not accessible."
  exit 1
fi

cd "$SCRIPT_DIR"

# Run configuration setup.
chmod +x embedded-system-manager/config_setup.sh
if ! source embedded-system-manager/config_setup.sh; then
  echo "Configuration setup failed or was cancelled."
  cd "$SCRIPT_DIR" 2>/dev/null || true
  exit 1
fi

# Ensure we're back in the script directory after config_setup
if [ ! -d "$SCRIPT_DIR" ]; then
  echo "ERROR: Script directory no longer exists."
  exit 1
fi

if ! cd "$SCRIPT_DIR"; then
  echo "ERROR: Failed to return to script directory."
  exit 1
fi

# Verify config file was created successfully
if [ ! -f "embedded-system-manager/config" ]; then
  echo "ERROR: Configuration file was not created."
  exit 1
fi

echo "Copying script directory to /opt directory..."

# Install embedded-system-manager
cp -rf embedded-system-manager /opt

# Get rid of windows /r newlines to prevent bugs
sed -i 's/\r$//' /opt/embedded-system-manager/*

echo "Making scripts executable..."

# Set all scripts to root executable permissions
chmod 744 /opt/embedded-system-manager/*.sh

echo "Copying systemd embedded-system-deployer.service file to /etc/systemd/system directory..."

# Installing embedded-system-deployer systemd service
cp -f embedded-system-deployer.service /etc/systemd/system

echo "Setting appropriate permissions for embedded-system-deployer.service..."

# Setting systemd service to appropriate permissions
chmod 664 /etc/systemd/system/embedded-system-deployer.service

echo "Creating new command 'edman'..."

# Installing edman command
cp edman /usr/bin

# Setting edman command to appropriate permissions
chmod 755 /usr/bin/edman


# Load the generated config to get deployment type
if ! source /opt/embedded-system-manager/config; then
	echo "ERROR: Failed to load configuration file."
	exit 1
fi

# Load paths configuration if it exists
if [ -f /opt/embedded-system-manager/paths.conf ]; then
	source /opt/embedded-system-manager/paths.conf
fi

# Perform initial deployment based on type
case "$deployment_source_type" in
	git)
		echo "Cloning repository into $script_workspace..."
		full_repo_refresh=1
		if ! source /opt/embedded-system-manager/install_repository.sh; then
			echo "ERROR: Failed to clone repository during setup."
			exit 1
		fi
		;;
	binary)
		echo "Initial binary deployment will occur on first service start."
		;;
	package)
		echo "Initial package installation will occur on first service start."
		;;
esac

echo "Enabling and starting embedded-system-deployer.service..."
# Enabling and starting embedded-system-deployer systemd service
systemctl enable embedded-system-deployer.service
systemctl start embedded-system-deployer.service

echo "Setup complete."

# Return to the original directory where the script was first run
if [ -d "$SCRIPT_DIR" ]; then
  if ! cd "$SCRIPT_DIR"; then
    echo "WARNING: Failed to return to original directory."
  fi
else
  echo "WARNING: Original script directory no longer exists."
fi
