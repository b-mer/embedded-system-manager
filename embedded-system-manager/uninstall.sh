#!/bin/bash
set -euo pipefail

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
if [ "$(id -u)" -ne 0 ]; then
	echo "This requires root privileges to run."
	exit 1
fi

# Load config to get script_workspace location
if [ -f /opt/embedded-system-manager/config ]; then
	source /opt/embedded-system-manager/config
else
	echo "Warning: Config file not found. Will proceed with default locations."
	script_workspace="/scripts"
fi

# Confirmation dialog
if ! whiptail --title "Uninstall Embedded System Manager" \
	--yesno "This will completely remove Embedded System Manager from your system.\n\nThe following will be removed:\n- /opt/embedded-system-manager/\n- /usr/bin/edman\n- /etc/systemd/system/embedded-system-deployer.service\n\nDo you want to continue?" \
	15 70 3>&1 1>&2 2>&3 < /dev/tty; then
	echo "Uninstall cancelled."
	exit 0
fi

# Ask about deployed content
REMOVE_DEPLOYED=0
if [ -d "$script_workspace" ]; then
	if whiptail --title "Remove Deployed Content" \
		--yesno "Do you also want to remove the deployed content at:\n$script_workspace\n\nThis may contain your application data." \
		12 70 3>&1 1>&2 2>&3 < /dev/tty; then
		REMOVE_DEPLOYED=1
	fi
fi

echo "Starting uninstall process..."

# Stop and disable the service
echo "Stopping embedded-system-deployer service..."
systemctl stop embedded-system-deployer.service 2>/dev/null || true

echo "Disabling embedded-system-deployer service..."
systemctl disable embedded-system-deployer.service 2>/dev/null || true

# Remove service file
echo "Removing service file..."
rm -f /etc/systemd/system/embedded-system-deployer.service

# Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Remove deployed content if requested
if [ $REMOVE_DEPLOYED -eq 1 ]; then
	echo "Removing deployed content at $script_workspace..."
	rm -rf "$script_workspace"
fi

# Remove main installation directory
echo "Removing /opt/embedded-system-manager/..."
rm -rf /opt/embedded-system-manager/

# Remove edman command
echo "Removing edman command..."
rm -f /usr/bin/edman

echo ""
echo "========================================="
echo "Embedded System Manager has been successfully uninstalled."
echo "========================================="
echo ""

if [ $REMOVE_DEPLOYED -eq 0 ] && [ -d "$script_workspace" ]; then
	echo "Note: Deployed content at $script_workspace was preserved."
fi
