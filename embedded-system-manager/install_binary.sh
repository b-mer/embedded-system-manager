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
	echo "Please run as root."
	exit 1
fi

# Create workspace directory if it doesn't exist
mkdir -p "$script_workspace"

BINARY_PATH="$script_workspace/$binary_name"
TEMP_BINARY="$script_workspace/.${binary_name}.tmp"

# Cleanup function for temporary files
cleanup() {
	rm -f "$TEMP_BINARY"
}

# Set trap to cleanup on exit or interrupt
trap cleanup EXIT INT TERM


# Verify checksum if provided
verify_checksum() {
	local file="$1"
	
	if [ -z "$binary_checksum" ]; then
		return 0
	fi
	
	echo "Verifying checksum..."
	local computed_checksum=$(sha256sum "$file" | awk '{print $1}')
	
	if [ "$computed_checksum" = "$binary_checksum" ]; then
		echo "Checksum verified successfully."
		return 0
	else
		echo "ERROR: Checksum mismatch!"
		echo "Expected: $binary_checksum"
		echo "Got: $computed_checksum"
		return 1
	fi
}

# Download binary with retry logic
download_binary() {
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
			echo "Retry attempt $retry_count of $max_retries..."
			sleep 2
		fi
		
		echo "Downloading binary from $binary_url..."
		
		local curl_args=(-fsSL -o "$TEMP_BINARY")
		
		if [ -n "$binary_auth_token" ]; then
			curl_args+=(-H "Authorization: Bearer $binary_auth_token")
		elif [ -n "$binary_auth_user" ] && [ -n "$binary_auth_pass" ]; then
			curl_args+=(-u "$binary_auth_user:$binary_auth_pass")
		fi
		
		curl_args+=("$binary_url")
		
		if curl "${curl_args[@]}"; then
			if verify_checksum "$TEMP_BINARY"; then
				chmod +x "$TEMP_BINARY"
				mv "$TEMP_BINARY" "$BINARY_PATH"
				echo "Binary downloaded and installed successfully."
				return 0
			else
				echo "ERROR: Checksum verification failed."
				rm -f "$TEMP_BINARY"
				retry_count=$((retry_count + 1))
			fi
		else
			echo "ERROR: Failed to download binary."
			rm -f "$TEMP_BINARY"
			retry_count=$((retry_count + 1))
		fi
	done
	
	echo "ERROR: Failed to download binary after $max_retries attempts."
	# Log the failure
	LOG_DIR="/var/log/embedded-system-manager"
	if mkdir -p "$LOG_DIR" 2>/dev/null && [ -w "$LOG_DIR" ]; then
		echo "Binary download failed after $max_retries attempts at $(date)" >> "$LOG_DIR/binary.log" 2>/dev/null || true
	else
		echo "WARNING: Could not write to log file at $LOG_DIR/binary.log"
	fi
	return 1
}

# Main logic
if [ -f "$BINARY_PATH" ] && [ "$binary_update_check" -eq 0 ]; then
	echo "Binary already exists and update check is disabled. Skipping download."
elif download_binary; then
	echo "Binary installation complete."
else
	if [ -f "$BINARY_PATH" ]; then
		echo "Download failed, but keeping existing binary."
	else
		echo "ERROR: No binary available to run."
		exit 1
	fi
fi
