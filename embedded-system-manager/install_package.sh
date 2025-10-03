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
if [ "$(id -u)" -ne 0 ]; then
	echo "Please run as root."
	exit 1
fi

# Create workspace directory if it doesn't exist
mkdir -p "$script_workspace"

TEMP_PACKAGE="$script_workspace/.package.tmp"
TEMP_EXTRACT="$script_workspace/.extract.tmp"


# Verify checksum if provided
verify_checksum() {
	local file="$1"
	
	if [ -z "$package_checksum" ]; then
		return 0
	fi
	
	echo "Verifying checksum..."
	local computed_checksum=$(sha256sum "$file" | awk '{print $1}')
	
	if [ "$computed_checksum" = "$package_checksum" ]; then
		echo "Checksum verified successfully."
		return 0
	else
		echo "ERROR: Checksum mismatch!"
		echo "Expected: $package_checksum"
		echo "Got: $computed_checksum"
		return 1
	fi
}

# Install .deb package
install_deb_package() {
	local package_file="$1"
	
	echo "Installing .deb package..."
	if dpkg -i "$package_file"; then
		echo "Package installed successfully."
		return 0
	else
		echo "ERROR: Failed to install .deb package."
		echo "Attempting to fix dependencies..."
		apt-get install -f -y
		return 1
	fi
}

# Download and install package
download_and_install_package() {
	echo "Downloading package from $package_url..."
	
	local curl_args=(-fsSL -o "$TEMP_PACKAGE")
	
	if [ -n "$package_auth_token" ]; then
		curl_args+=(-H "Authorization: Bearer $package_auth_token")
	elif [ -n "$package_auth_user" ] && [ -n "$package_auth_pass" ]; then
		curl_args+=(-u "$package_auth_user:$package_auth_pass")
	fi
	
	curl_args+=("$package_url")
	
	if ! curl "${curl_args[@]}"; then
		echo "ERROR: Failed to download package."
		rm -f "$TEMP_PACKAGE"
		return 1
	fi
	
	if ! verify_checksum "$TEMP_PACKAGE"; then
		rm -f "$TEMP_PACKAGE"
		return 1
	fi
	
	# Detect package type from URL or file
	if [[ "$package_url" == *.deb ]] || file "$TEMP_PACKAGE" | grep -q "Debian binary package"; then
		install_deb_package "$TEMP_PACKAGE"
		local result=$?
		rm -f "$TEMP_PACKAGE"
		return $result
	else
		echo "ERROR: Unsupported package type. Currently only .deb packages are supported."
		rm -f "$TEMP_PACKAGE"
		return 1
	fi
}

# Check if package needs updating
needs_update() {
	# If update check is disabled and we have files in workspace, skip
	if [ $package_update_check -eq 0 ] && [ "$(ls -A $script_workspace 2>/dev/null)" ]; then
		return 1
	fi
	return 0
}

# Main logic
if needs_update; then
	if download_and_install_package; then
		echo "Package installation complete."
	else
		echo "ERROR: Package installation failed."
		if [ "$(ls -A $script_workspace 2>/dev/null)" ]; then
			echo "Keeping existing installation."
		else
			exit 1
		fi
	fi
else
	echo "Package already installed and update check is disabled. Skipping download."
fi
