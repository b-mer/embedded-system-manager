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
		BINARY_URL=$(whiptail --inputbox "Binary download URL:" 8 80 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
		if [ "$?" = 1 ]; then
			echo "Configuration setup cancelled."
			exit 1
		fi

		BINARY_NAME=$(whiptail --inputbox "Binary filename:" 8 60 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
		if [ "$?" = 1 ]; then
			echo "Configuration setup cancelled."
			exit 1
		fi

		BINARY_CHECKSUM=$(whiptail --inputbox "SHA256 checksum (optional, leave blank to skip):" 10 80 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
		if [ "$?" = 1 ]; then
			echo "Configuration setup cancelled."
			exit 1
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
			
			if [ "$AUTH_TYPE" = "token" ]; then
				BINARY_AUTH_TOKEN=$(whiptail --inputbox "Bearer token:" 8 80 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
				BINARY_AUTH_USER=""
				BINARY_AUTH_PASS=""
			elif [ "$AUTH_TYPE" = "basic" ]; then
				BINARY_AUTH_USER=$(whiptail --inputbox "Username:" 8 60 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
				BINARY_AUTH_PASS=$(whiptail --passwordbox "Password:" 8 60 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
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
		PACKAGE_URL=$(whiptail --inputbox "Package download URL (.deb):" 8 80 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
		if [ "$?" = 1 ]; then
			echo "Configuration setup cancelled."
			exit 1
		fi

		PACKAGE_CHECKSUM=$(whiptail --inputbox "SHA256 checksum (optional, leave blank to skip):" 10 80 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
		if [ "$?" = 1 ]; then
			echo "Configuration setup cancelled."
			exit 1
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
			
			if [ "$AUTH_TYPE" = "token" ]; then
				PACKAGE_AUTH_TOKEN=$(whiptail --inputbox "Bearer token:" 8 80 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
				PACKAGE_AUTH_USER=""
				PACKAGE_AUTH_PASS=""
			elif [ "$AUTH_TYPE" = "basic" ]; then
				PACKAGE_AUTH_USER=$(whiptail --inputbox "Username:" 8 60 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
				PACKAGE_AUTH_PASS=$(whiptail --passwordbox "Password:" 8 60 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
				PACKAGE_AUTH_TOKEN=""
			fi
		else
			PACKAGE_AUTH_TOKEN=""
			PACKAGE_AUTH_USER=""
			PACKAGE_AUTH_PASS=""
		fi
	fi

	while true; do
		DEPLOY_LOCATION=$(whiptail --inputbox "Deploy path (where your program will be deployed to):" 8 70 --title "$SETUP_TITLE" "/scripts" 3>&1 1>&2 2>&3 < /dev/tty)
		if [ "$?" = 1 ]; then
		echo "Configuration setup cancelled."
			exit 1
		fi
		if mkdir -p "$DEPLOY_LOCATION" &>/dev/null; then
			# Verify write permissions
			if [ ! -w "$DEPLOY_LOCATION" ]; then
				whiptail --msgbox "Path exists but is not writable. Try again." 8 50 < /dev/tty
				continue
			fi
			# Check available disk space (at least 100MB)
			available_space=$(df -BM "$DEPLOY_LOCATION" | awk 'NR==2 {print $4}' | sed 's/M//')
			if [ "$available_space" -lt 100 ]; then
				whiptail --msgbox "Insufficient disk space (need at least 100MB). Try again." 8 60 < /dev/tty
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
		REPO_RUN_COMMAND=""
		PACKAGE_RUN_COMMAND=""
	elif [ "$DEPLOYMENT_TYPE" = "package" ]; then
		PACKAGE_RUN_COMMAND=$(whiptail --inputbox "Command to run the installed package (e.g., 'myapp --start'):" 10 70 --title "$SETUP_TITLE" 3>&1 1>&2 2>&3 < /dev/tty)
		if [ "$?" = 1 ]; then
			echo "Configuration setup cancelled."
			exit 1
		fi
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
		"Full repo refresh" "Have the repository reclone itself rather than just git pull (git only)." OFF \
		"Check for System Updates" "Check for latest updates each boot using apt." OFF \
		"Run program" "Run the deployed program on startup." ON 3>&1 1>&2 2>&3 < /dev/tty)
	if [ "$?" = 1 ]; then
		echo "Configuration setup cancelled."
		exit 1
	fi

	# Convert choices to array (whiptail returns space-separated quoted strings)
	eval "selected=($choices)"

	full_repo_refresh=0
	check_for_package_updates=0
	run_script=0

	for choice in "${selected[@]}"; do
		case "$choice" in
			"Full repo refresh") full_repo_refresh=1 ;;
			"Check for System Updates") check_for_package_updates=1 ;;
			"Run program") run_script=1 ;;
		esac
	done

	# Generate config file based on deployment type
	cat > "$CONFIG_FILE" <<EOF
# GENERATED BY SETUP SCRIPT

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

EOF

	# Return to original directory
	cd "$ORIGINAL_DIR"
}

configuration_setup
cat $CONFIG_FILE
