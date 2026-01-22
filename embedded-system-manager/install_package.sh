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

# Check if root
if [ "$(id -u)" -ne 0 ]; then
	echo "Please run as root."
	exit 1
fi

# Package name cache directory
CACHE_DIR="/var/lib/embedded-system-manager"
PACKAGE_CACHE="$CACHE_DIR/installed-package-name"

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR" 2>/dev/null || true

# Use system temp directory for .deb downloads (packages install to system locations)
# No need to create script_workspace for .deb packages
TEMP_PACKAGE=$(mktemp "/tmp/XXXXXX.deb")

# Cleanup function for temporary files
cleanup() {
	rm -f "$TEMP_PACKAGE"
}

# Set trap to cleanup on exit or interrupt
trap cleanup EXIT INT TERM


# Verify checksum if provided
verify_checksum() {
	local file="$1"
	
	if [ -z "$package_checksum" ]; then
		echo "WARNING: No checksum provided. Deployment is unverified."
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

# Extract package name from .deb file
get_package_name() {
	local package_file="$1"
	dpkg-deb -f "$package_file" Package 2>/dev/null || echo ""
}

# Extract package name from URL (fallback when .deb file not available)
get_package_name_from_url() {
	local url="$1"
	local filename=$(basename "$url" .deb)
	
	# Try Debian naming convention: packagename_version_arch.deb
	if [[ "$filename" =~ ^([a-z0-9][a-z0-9+.-]+)_[0-9] ]]; then
		echo "${BASH_REMATCH[1]}"
		return 0
	fi
	
	# Fallback: strip common version/arch suffixes
	# Handles cases like: myapp-v2.0-amd64, myapp-1.2.3, etc.
	echo "$filename" | sed -E 's/[-_](v?[0-9]+\.[0-9]+[^-_]*|amd64|arm64|armhf|i386|all)$//g' | sed -E 's/[-_](v?[0-9]+\.[0-9]+[^-_]*)$//g'
}

# Check if a .deb package is installed
is_package_installed() {
	local package_name="$1"
	if [ -z "$package_name" ]; then
		return 1
	fi
	
	# Validate package name format (Debian Policy compliant)
	if ! [[ "$package_name" =~ ^[a-z0-9][a-z0-9+.-]*$ ]]; then
		return 1
	fi
	
	dpkg -l "$package_name" 2>/dev/null | grep -q "^ii"
}

# Install .deb package
install_deb_package() {
	local package_file="$1"
	local package_name="$2"
	
	echo "Installing .deb package..."
	if dpkg -i "$package_file"; then
		echo "Package installed successfully."
		
		# Cache the package name for future update checks
		if [ -n "$package_name" ]; then
			echo "$package_name" > "$PACKAGE_CACHE" 2>/dev/null || true
		fi
		
		return 0
	else
		echo "ERROR: Failed to install .deb package."
		echo "Attempting to fix dependencies..."
		apt-get update && apt-get install -f -y
		return 1
	fi
}

# Download package with retry logic
download_package() {
	# Use configured retry value, default to 3 if not set
	local max_retries="${download_max_retries:-3}"
	# Validate max_retries is a positive integer
	if ! [[ "$max_retries" =~ ^[0-9]+$ ]] || [ "$max_retries" -lt 1 ]; then
		echo "ERROR: Invalid download_max_retries value: $max_retries (must be positive integer)"
		return 1
	fi
	local retry_count=0
	
	while [ $retry_count -lt $max_retries ]; do
		if [ $retry_count -gt 0 ]; then
			local delay=$((2 ** retry_count))
			echo "Retry attempt $retry_count of $max_retries... Sleeping ${delay}s"
			sleep $delay
		fi
		
		echo "Downloading package from $package_url..."
		
		local curl_args=(-fsSL -o "$TEMP_PACKAGE")
		
		if [ -n "$package_auth_token" ]; then
			curl_args+=(-H "Authorization: Bearer $package_auth_token")
		elif [ -n "$package_auth_user" ] && [ -n "$package_auth_pass" ]; then
			curl_args+=(-u "$package_auth_user:$package_auth_pass")
		fi
		
		curl_args+=("$package_url")
		
		if curl "${curl_args[@]}"; then
			if verify_checksum "$TEMP_PACKAGE"; then
				return 0
			else
				echo "ERROR: Checksum verification failed."
				rm -f "$TEMP_PACKAGE"
				retry_count=$((retry_count + 1))
			fi
		else
			echo "ERROR: Failed to download package."
			rm -f "$TEMP_PACKAGE"
			retry_count=$((retry_count + 1))
		fi
	done
	
	echo "ERROR: Failed to download package after $max_retries attempts."
	# Log the failure
	LOG_DIR="/var/log/embedded-system-manager"
	if mkdir -p "$LOG_DIR" 2>/dev/null && [ -w "$LOG_DIR" ]; then
		echo "Package download failed after $max_retries attempts at $(date)" >> "$LOG_DIR/package.log" 2>/dev/null || true
	else
		echo "WARNING: Could not write to log file at $LOG_DIR/package.log"
	fi
	return 1
}

# Check if package needs updating
needs_update() {
	# If update check is disabled, check if package is already installed
	if [ "$package_update_check" -eq 0 ]; then
		# First, check the cache for previously installed package name
		if [ -f "$PACKAGE_CACHE" ]; then
			local cached_package_name=$(cat "$PACKAGE_CACHE" 2>/dev/null)
			if [ -n "$cached_package_name" ] && is_package_installed "$cached_package_name"; then
				echo "Package $cached_package_name is already installed (from cache). Skipping download."
				return 1  # Package installed, skip update
			fi
		fi
		
		# Fallback: Try to extract package name from URL
		local package_name_from_url=$(get_package_name_from_url "$package_url")
		if is_package_installed "$package_name_from_url"; then
			echo "Package $package_name_from_url is already installed. Skipping download."
			return 1  # Package installed, skip update
		fi
	fi
	return 0  # Proceed with download/install
}

# Main logic
if needs_update; then
	if download_package; then
		# Detect package type from URL or file
		if [[ "$package_url" == *.deb ]] || file "$TEMP_PACKAGE" | grep -q "Debian binary package"; then
			# Extract package name before installation
			PACKAGE_NAME=$(get_package_name "$TEMP_PACKAGE")
			
			if install_deb_package "$TEMP_PACKAGE" "$PACKAGE_NAME"; then
				echo "Package installation complete."
				rm -f "$TEMP_PACKAGE"
			else
				echo "ERROR: Package installation failed."
				rm -f "$TEMP_PACKAGE"
				# Check if package is already installed (fallback to existing installation)
				if [ -n "$PACKAGE_NAME" ] && is_package_installed "$PACKAGE_NAME"; then
					echo "Keeping existing installation of $PACKAGE_NAME."
				else
					exit 1
				fi
			fi
		else
			echo "ERROR: Unsupported package type. Currently only .deb packages are supported."
			rm -f "$TEMP_PACKAGE"
			exit 1
		fi
	else
		echo "ERROR: Package download failed."
		# Check if a version of the package is already installed
		local package_name_from_url=$(get_package_name_from_url "$package_url")
		if is_package_installed "$package_name_from_url"; then
			echo "Keeping existing installation of $package_name_from_url."
		else
			exit 1
		fi
	fi
else
	echo "Package already installed and update check is disabled. Skipping download."
fi
