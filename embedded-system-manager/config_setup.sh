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

CONFIG_FILE="$(dirname "$BASH_SOURCE")/config"

# Configuration setup.
configuration_setup() {
	
	# Save original directory to return to it later
	ORIGINAL_DIR="$(pwd)"

	SETUP_TITLE="Embedded System Manager Setup"

	# Select deployment source type
	DEPLOYMENT_TYPE=$(whiptail --title "$SETUP_TITLE" --menu "Choose deployment source type:" 15 60 3 \
		"git" "Git repository (clone/pull)" \
		"binary" "Binary file download" \
		"package" "Package download (.deb)" \
		3>&1 1>&2 2>&3 < /dev/tty)
	
	if [ "$?" = 1 ]; then
		echo "Configuration setup cancelled."
		exit 1
	fi

	# Initialize all variables to empty strings first
	GIT_REPO=""
	GIT_REPO_BRANCH=""
	BINARY_URL=""
	BINARY_NAME=""
	BINARY_CHECKSUM=""
	BINARY_UPDATE_CHECK=0
	BINARY_AUTH_TOKEN=""
	BINARY_AUTH_USER=""
	BINARY_AUTH_PASS=""
	PACKAGE_URL=""
	PACKAGE_CHECKSUM=""
	PACKAGE_UPDATE_CHECK=0
	PACKAGE_AUTH_TOKEN=""
	PACKAGE_AUTH_USER=""
	PACKAGE_AUTH_PASS=""

	# Git repository setup
	if [ "$DEPLOYMENT_TYPE" = "git" ]; then
		while true; do
			GIT_REPO=$(whiptail --inputbox "Git repository clone link:" 8 80 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3  < /dev/tty)
			if [ "$?" = 1 ]; then
				echo "Configuration setup cancelled."
				exit 1
			fi
			# Run git command and show progress with infobox
			whiptail --infobox "Checking if repository can be accessed...\n\nPlease wait..." 8 50 < /dev/tty
			GIT_TERMINAL_PROMPT=0 git ls-remote --exit-code "$GIT_REPO" >/dev/null 2>&1
			exit_code=$?
			if [ "$exit_code" -eq 0 ]; then
				break
			else
				whiptail --msgbox "Can't access git repository!" --title "$SETUP_TITLE" 8 40 < /dev/tty
			fi
		done

		while true; do
			GIT_REPO_BRANCH=$(whiptail --inputbox "Branch name (leave blank to use default branch):" 10 40 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
			if [ "$?" = 1 ]; then
				echo "Configuration setup cancelled."
				exit 1
			fi
			# Run git command and show progress with infobox
			whiptail --infobox "Checking if branch can be accessed...\n\nPlease wait..." 8 50 < /dev/tty
			GIT_TERMINAL_PROMPT=0 git ls-remote --exit-code "$GIT_REPO" "$GIT_REPO_BRANCH" >/dev/null 2>&1
			exit_code=$?
			if [ "$exit_code" -eq 0 ] || [ -z "$GIT_REPO_BRANCH" ]; then
				break
			else
				whiptail --msgbox "Can't access $GIT_REPO_BRANCH branch!" --title "$SETUP_TITLE" 8 40 < /dev/tty
			fi
		done
	fi

	# Binary download setup
	if [ "$DEPLOYMENT_TYPE" = "binary" ]; then
		while true; do
			BINARY_URL=$(whiptail --inputbox "Binary download URL:" 8 80 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
			if [ "$?" = 1 ]; then
				echo "Configuration setup cancelled."
				exit 1
			fi
			if [ -z "$BINARY_URL" ]; then
				whiptail --msgbox "Binary URL cannot be empty!" --title "$SETUP_TITLE" 8 40 < /dev/tty
			else
				break
			fi
		done

		while true; do
			BINARY_NAME=$(whiptail --inputbox "Binary filename:" 8 60 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
			if [ "$?" = 1 ]; then
				echo "Configuration setup cancelled."
				exit 1
			fi
			if [ -z "$BINARY_NAME" ]; then
				whiptail --msgbox "Binary filename cannot be empty!" --title "$SETUP_TITLE" 8 40 < /dev/tty
			else
				break
			fi
		done

		BINARY_CHECKSUM=$(whiptail --inputbox "SHA256 checksum (optional, leave blank to skip):" 10 80 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
		if [ "$?" = 1 ]; then
			echo "Configuration setup cancelled."
			exit 1
		fi
		
		# Validate checksum format if provided
		if [ -n "$BINARY_CHECKSUM" ]; then
			if ! [[ "$BINARY_CHECKSUM" =~ ^[a-fA-F0-9]{64}$ ]]; then
				whiptail --msgbox "Invalid SHA256 checksum format! Must be 64 hexadecimal characters. Proceeding without checksum verification." --title "$SETUP_TITLE" 10 60 < /dev/tty
				BINARY_CHECKSUM=""
			fi
		fi

		if whiptail --title "$SETUP_TITLE" --yesno "Re-download binary on each boot?" 8 50 3>&1 1>&2 2>&3 < /dev/tty; then
			BINARY_UPDATE_CHECK=1
		else
			BINARY_UPDATE_CHECK=0
		fi

		if whiptail --title "$SETUP_TITLE" --yesno "Does this download require authentication?" 8 50 3>&1 1>&2 2>&3 < /dev/tty; then
			AUTH_TYPE=$(whiptail --title "$SETUP_TITLE" --menu "Choose authentication type:" 12 60 2 \
				"token" "Bearer token" \
				"basic" "Basic auth (username/password)" \
				3>&1 1>&2 2>&3 < /dev/tty)
			
			if [ "$?" = 1 ]; then
				echo "Configuration setup cancelled."
				exit 1
			fi
			
			if [ "$AUTH_TYPE" = "token" ]; then
				BINARY_AUTH_TOKEN=$(whiptail --inputbox "Bearer token:" 8 80 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
				if [ "$?" = 1 ]; then
					echo "Configuration setup cancelled."
					exit 1
				fi
				BINARY_AUTH_USER=""
				BINARY_AUTH_PASS=""
			elif [ "$AUTH_TYPE" = "basic" ]; then
				BINARY_AUTH_USER=$(whiptail --inputbox "Username:" 8 60 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
				if [ "$?" = 1 ]; then
					echo "Configuration setup cancelled."
					exit 1
				fi
				BINARY_AUTH_PASS=$(whiptail --passwordbox "Password:" 8 60 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
				if [ "$?" = 1 ]; then
					echo "Configuration setup cancelled."
					exit 1
				fi
				BINARY_AUTH_TOKEN=""
			fi
		else
			BINARY_AUTH_TOKEN=""
			BINARY_AUTH_USER=""
			BINARY_AUTH_PASS=""
		fi
	fi

	# Package download setup
	if [ "$DEPLOYMENT_TYPE" = "package" ]; then
		while true; do
			PACKAGE_URL=$(whiptail --inputbox "Package download URL (.deb):" 8 80 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
			if [ "$?" = 1 ]; then
				echo "Configuration setup cancelled."
				exit 1
			fi
			if [ -z "$PACKAGE_URL" ]; then
				whiptail --msgbox "Package URL cannot be empty!" --title "$SETUP_TITLE" 8 40 < /dev/tty
			else
				break
			fi
		done

		PACKAGE_CHECKSUM=$(whiptail --inputbox "SHA256 checksum (optional, leave blank to skip):" 10 80 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
		if [ "$?" = 1 ]; then
			echo "Configuration setup cancelled."
			exit 1
		fi
		
		# Validate checksum format if provided
		if [ -n "$PACKAGE_CHECKSUM" ]; then
			if ! [[ "$PACKAGE_CHECKSUM" =~ ^[a-fA-F0-9]{64}$ ]]; then
				whiptail --msgbox "Invalid SHA256 checksum format! Must be 64 hexadecimal characters. Proceeding without checksum verification." --title "$SETUP_TITLE" 10 60 < /dev/tty
				PACKAGE_CHECKSUM=""
			fi
		fi

		if whiptail --title "$SETUP_TITLE" --yesno "Re-download package on each boot?" 8 50 3>&1 1>&2 2>&3 < /dev/tty; then
			PACKAGE_UPDATE_CHECK=1
		else
			PACKAGE_UPDATE_CHECK=0
		fi

		if whiptail --title "$SETUP_TITLE" --yesno "Does this download require authentication?" 8 50 3>&1 1>&2 2>&3 < /dev/tty; then
			AUTH_TYPE=$(whiptail --title "$SETUP_TITLE" --menu "Choose authentication type:" 12 60 2 \
				"token" "Bearer token" \
				"basic" "Basic auth (username/password)" \
				3>&1 1>&2 2>&3 < /dev/tty)
			
			if [ "$?" = 1 ]; then
				echo "Configuration setup cancelled."
				exit 1
			fi
			
			if [ "$AUTH_TYPE" = "token" ]; then
				PACKAGE_AUTH_TOKEN=$(whiptail --inputbox "Bearer token:" 8 80 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
				if [ "$?" = 1 ]; then
					echo "Configuration setup cancelled."
					exit 1
				fi
				PACKAGE_AUTH_USER=""
				PACKAGE_AUTH_PASS=""
			elif [ "$AUTH_TYPE" = "basic" ]; then
				PACKAGE_AUTH_USER=$(whiptail --inputbox "Username:" 8 60 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
				if [ "$?" = 1 ]; then
					echo "Configuration setup cancelled."
					exit 1
				fi
				PACKAGE_AUTH_PASS=$(whiptail --passwordbox "Password:" 8 60 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
				if [ "$?" = 1 ]; then
					echo "Configuration setup cancelled."
					exit 1
				fi
				PACKAGE_AUTH_TOKEN=""
			fi
		else
			PACKAGE_AUTH_TOKEN=""
			PACKAGE_AUTH_USER=""
			PACKAGE_AUTH_PASS=""
		fi
	fi

	# Protected system paths that should not be used as deployment locations
	PROTECTED_PATHS=(
		"/"
		"/bin"
		"/boot"
		"/dev"
		"/etc"
		"/lib"
		"/lib64"
		"/proc"
		"/root"
		"/sbin"
		"/sys"
		"/usr"
		"/var"
	)

	while true; do
		DEPLOY_LOCATION=$(whiptail --inputbox "Deploy path (where your program will be deployed to):" 8 70 --title "$SETUP_TITLE" "/scripts" 3>&1 1>&2 2>&3 < /dev/tty)
		if [ "$?" = 1 ]; then
		echo "Configuration setup cancelled."
			exit 1
		fi
		
		# Validate against protected paths
		is_protected=false
		for protected in "${PROTECTED_PATHS[@]}"; do
			if [ "$DEPLOY_LOCATION" = "$protected" ]; then
				is_protected=true
				break
			fi
		done
		
		if [ "$is_protected" = true ]; then
			whiptail --msgbox "Cannot use protected system directory: $DEPLOY_LOCATION\nPlease choose a different path." 10 60 < /dev/tty
			continue
		fi
		
		# Validate path doesn't contain dangerous characters
		if [[ "$DEPLOY_LOCATION" =~ [[:space:]\;\&\|\$\`] ]]; then
			whiptail --msgbox "Path contains invalid characters. Try again." 8 50 < /dev/tty
			continue
		fi
		
		if mkdir -p "$DEPLOY_LOCATION" &>/dev/null; then
			# Verify write permissions
			if [ ! -w "$DEPLOY_LOCATION" ]; then
				whiptail --msgbox "Path exists but is not writable. Try again." 8 50 < /dev/tty
				continue
			fi
			# Check available disk space (at least 500MB for safety)
			available_space=$(df -BM "$DEPLOY_LOCATION" | awk 'NR==2 {print $4}' | sed 's/M//')
			if [ "$available_space" -lt 500 ]; then
				whiptail --msgbox "Insufficient disk space (need at least 500MB). Try again." 8 60 < /dev/tty
				continue
			fi
			break
		else
			whiptail --msgbox "Invalid path. Try again." 8 40 < /dev/tty
		fi
	done

	# Get deployment-specific run configuration
	if [ "$DEPLOYMENT_TYPE" = "git" ]; then
		REPO_RUN_COMMAND=$(whiptail --inputbox "Command to run in the repository (leave blank for 'source main.*'):" 10 70 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
		if [ "$?" = 1 ]; then
			echo "Configuration setup cancelled."
			exit 1
		fi
		# Set default if blank
		if [ -z "$REPO_RUN_COMMAND" ]; then
			REPO_RUN_COMMAND="source main.*"
		fi
		BINARY_RUN_FLAGS=""
		PACKAGE_RUN_COMMAND=""
	elif [ "$DEPLOYMENT_TYPE" = "binary" ]; then
		BINARY_RUN_FLAGS=$(whiptail --inputbox "Flags/arguments to pass when running the binary (optional):" 10 70 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
		if [ "$?" = 1 ]; then
			echo "Configuration setup cancelled."
			exit 1
		fi
		# Trim whitespace
		BINARY_RUN_FLAGS=$(echo "$BINARY_RUN_FLAGS" | xargs)
		REPO_RUN_COMMAND=""
		PACKAGE_RUN_COMMAND=""
	elif [ "$DEPLOYMENT_TYPE" = "package" ]; then
		PACKAGE_RUN_COMMAND=$(whiptail --inputbox "Command to run the installed package (e.g., 'myapp --start'):" 10 70 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
		if [ "$?" = 1 ]; then
			echo "Configuration setup cancelled."
			exit 1
		fi
		# Trim whitespace
		PACKAGE_RUN_COMMAND=$(echo "$PACKAGE_RUN_COMMAND" | xargs)
		REPO_RUN_COMMAND=""
		BINARY_RUN_FLAGS=""
	fi

	# Cage Window Manager flag
	if whiptail --title "$SETUP_TITLE" --yesno "Do you want to run the program as a kiosk using Cage?" 8 60 3>&1 1>&2 2>&3 < /dev/tty; then
		run_in_cage=1
	else
		run_in_cage=0
	fi

	# Turning on/off simple flags
	choices=$(whiptail --title "$SETUP_TITLE" --checklist \
		"Choose misc options (space to tick/untick):" 15 110 3 \
		"FULL_REPO_REFRESH" "Have the repository reclone itself rather than just git pull (git only)." OFF \
		"CHECK_UPDATES" "Check for latest updates each boot using apt." OFF \
		"RUN_PROGRAM" "Run the deployed program on startup." ON 3>&1 1>&2 2>&3 < /dev/tty)
	if [ "$?" = 1 ]; then
		echo "Configuration setup cancelled."
		exit 1
	fi

	# Convert choices to array safely without eval
	full_repo_refresh=0
	check_for_package_updates=0
	run_script=0

	# Parse the choices string using stable identifiers instead of display text
	if echo "$choices" | grep -q "FULL_REPO_REFRESH"; then
		full_repo_refresh=1
	fi
	if echo "$choices" | grep -q "CHECK_UPDATES"; then
		check_for_package_updates=1
	fi
	if echo "$choices" | grep -q "RUN_PROGRAM"; then
		run_script=1
	fi

	# Generate config file based on deployment type
	cat > "$CONFIG_FILE" <<EOF
# GENERATED BY SETUP SCRIPT
# 
# SECURITY WARNING: This configuration file contains sensitive information
# including authentication tokens and passwords stored in plain text.
# Ensure this file has appropriate permissions (readable only by root).
# Consider using environment variables or a secrets management system
# for production deployments.

# Deployment source type
# Options: git, binary, package
deployment_source_type="$DEPLOYMENT_TYPE"

# ===== GIT REPOSITORY SETTINGS =====
# For repository
repository_url="$GIT_REPO"

# Leave as a blank string to by default clone from main/master
repository_branch="$GIT_REPO_BRANCH"

# Full repo refresh flag
# 1 = Delete existing clone and clone repo again on boot
# 0 = Just run git pull on boot
full_repo_refresh=$full_repo_refresh

# ===== BINARY DOWNLOAD SETTINGS =====
# URL to download binary from
binary_url="$BINARY_URL"

# Name to save the binary as
binary_name="$BINARY_NAME"

# SHA256 checksum for verification (optional, leave blank to skip)
binary_checksum="$BINARY_CHECKSUM"

# Binary update check flag
# 1 = Re-download binary on each boot
# 0 = Download once and keep
binary_update_check=$BINARY_UPDATE_CHECK

# Authentication (optional)
binary_auth_token="$BINARY_AUTH_TOKEN"
binary_auth_user="$BINARY_AUTH_USER"
binary_auth_pass="$BINARY_AUTH_PASS"

# ===== PACKAGE DOWNLOAD SETTINGS =====
# URL to download package from (currently supports .deb packages)
package_url="$PACKAGE_URL"

# SHA256 checksum for verification (optional, leave blank to skip)
package_checksum="$PACKAGE_CHECKSUM"

# Package update check flag
# 1 = Re-download package on each boot
# 0 = Download once and keep
package_update_check=$PACKAGE_UPDATE_CHECK

# Authentication (optional)
package_auth_token="$PACKAGE_AUTH_TOKEN"
package_auth_user="$PACKAGE_AUTH_USER"
package_auth_pass="$PACKAGE_AUTH_PASS"

# ===== COMMON SETTINGS =====
script_workspace="$DEPLOY_LOCATION"

# Command to run in the repository (git only)
repo_run_command="$REPO_RUN_COMMAND"

# Flags/arguments to pass when running the binary (binary only)
binary_run_flags="$BINARY_RUN_FLAGS"

# Command/flags to run the installed package (package only)
package_run_command="$PACKAGE_RUN_COMMAND"

# Package update flag
# 1 = Check for the latest updates from apt repositories
# 0 = Do not check for package updates
check_for_package_updates=$check_for_package_updates

# Run program flag
# 1 = Runs the deployed program
# 0 = Does not run the program at all
run_script=$run_script

# Cage Window Manager flag
# 1 = Set up and run code in Cage Window Manager
# 0 = Do not use Cage Window Manager
run_in_cage=$run_in_cage

# ===== ADVANCED SETTINGS =====
# Git operation timeout in seconds (default: 300)
git_timeout=300

# Download retry attempts (default: 3)
download_max_retries=3

EOF

	# Set restrictive permissions on config file (readable only by root)
	chmod 600 "$CONFIG_FILE"
	echo "Configuration file created with restricted permissions (600)."

	# Return to original directory
	cd "$ORIGINAL_DIR"
}

configuration_setup
cat $CONFIG_FILE
