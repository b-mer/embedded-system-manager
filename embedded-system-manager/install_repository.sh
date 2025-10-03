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

if [ $full_repo_refresh -eq 1 ]; then
	# Checks if script directory exists, if so, delete it to clear any older versions of the script
	if [ -d "$script_workspace" ]; then
		rm -rf "$script_workspace"
	fi

	# Make a new folder for the script
	mkdir "$script_workspace"

	# Clone repository into script directory
	echo "Cloning repository from $repository_url..."
	if [[ "$repository_branch" == "" ]]; then
		if ! git clone "$repository_url" "$script_workspace"; then
			echo "ERROR: Failed to clone repository."
			exit 1
		fi
	else
		if ! git clone --branch "$repository_branch" "$repository_url" "$script_workspace"; then
			echo "ERROR: Failed to clone repository."
			exit 1
		fi
	fi

	# Set executable permission for main file
	chmod +x "$script_workspace"/main.* 2>/dev/null || true
	echo "Repository cloned successfully."
else
	# Pull updates, but keep existing version if pull fails
	echo "Updating repository..."
	if [ ! -d "$script_workspace/.git" ]; then
		echo "ERROR: Repository directory exists but is not a git repository."
		echo "Please delete $script_workspace and run setup again, or enable full_repo_refresh."
		exit 1
	fi
	
	if git -C "$script_workspace" pull; then
		chmod +x "$script_workspace"/main.* 2>/dev/null || true
		echo "Repository updated successfully."
	else
		echo "ERROR: Failed to pull updates. Keeping existing version."
		# Only continue if we have a valid repository
		if [ ! -f "$script_workspace"/main.* ]; then
			echo "ERROR: No valid repository found to run."
			exit 1
		fi
	fi
fi
