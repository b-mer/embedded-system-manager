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

if [ "$full_repo_refresh" -eq 1 ]; then
	# Checks if script directory exists, if so, delete it to clear any older versions of the script
	if [ -d "$script_workspace" ]; then
		rm -rf "$script_workspace"
	fi

	# Make a new folder for the script
	if ! mkdir -p "$script_workspace"; then
		echo "ERROR: Failed to create directory $script_workspace"
		exit 1
	fi

	# Clone repository into script directory
	echo "Cloning repository from $repository_url..."
	# Use configured timeout value, default to 300 if not set
	GIT_TIMEOUT="${git_timeout:-300}"
	# Validate timeout is a positive integer
	if ! [[ "$GIT_TIMEOUT" =~ ^[0-9]+$ ]] || [ "$GIT_TIMEOUT" -lt 1 ]; then
		echo "ERROR: Invalid git_timeout value: $GIT_TIMEOUT (must be positive integer)"
		exit 1
	fi
	if [ -z "$repository_branch" ]; then
		if ! timeout "$GIT_TIMEOUT" git clone "$repository_url" "$script_workspace"; then
			echo "ERROR: Failed to clone repository (timeout or error)."
			exit 1
		fi
	else
		if ! timeout "$GIT_TIMEOUT" git clone --branch "$repository_branch" "$repository_url" "$script_workspace"; then
			echo "ERROR: Failed to clone repository (timeout or error)."
			exit 1
		fi
	fi

	echo "Repository cloned successfully."
else
	# Pull updates, but keep existing version if pull fails
	echo "Updating repository..."
	if [ ! -d "$script_workspace/.git" ]; then
		echo "ERROR: Repository directory exists but is not a git repository."
		echo "Please delete $script_workspace and run setup again, or enable full_repo_refresh."
		exit 1
	fi
	
	# Verify repository health before attempting pull
	echo "Verifying repository health..."
	if ! git -C "$script_workspace" rev-parse --git-dir >/dev/null 2>&1; then
		echo "ERROR: Repository is corrupted."
		echo "Please delete $script_workspace and run setup again, or enable full_repo_refresh."
		exit 1
	fi
	
	# Check if there are uncommitted changes that could cause conflicts
	if ! git -C "$script_workspace" diff-index --quiet HEAD -- 2>/dev/null; then
		echo "WARNING: Repository has uncommitted changes. Stashing them before pull..."
		if ! git -C "$script_workspace" stash push -m "Auto-stash before pull at $(date)" 2>/dev/null; then
			echo "WARNING: Failed to stash changes. Pull may fail or cause conflicts."
		fi
	fi
	
	# Check if repository is in detached HEAD state
	if ! git -C "$script_workspace" symbolic-ref HEAD >/dev/null 2>&1; then
		echo "WARNING: Repository is in detached HEAD state. Attempting to fix..."
		# Try to checkout the configured branch or default branch
		checkout_success=false
		if [ -n "$repository_branch" ]; then
			# Validate branch name doesn't contain dangerous characters
			if [[ "$repository_branch" =~ [[:space:]\;\&\|\$\`] ]]; then
				echo "ERROR: Branch name contains invalid characters: $repository_branch"
				echo "Please update your configuration with a valid branch name."
				exit 1
			fi
			# Verify the branch exists on remote before attempting checkout
			if git -C "$script_workspace" ls-remote --exit-code --heads origin "$repository_branch" >/dev/null 2>&1; then
				if git -C "$script_workspace" checkout "$repository_branch" 2>/dev/null; then
					checkout_success=true
					echo "Successfully checked out branch: $repository_branch"
				fi
			else
				echo "WARNING: Configured branch '$repository_branch' not found on remote."
			fi
		else
			# Try common default branches, verifying they exist on remote first
			for branch in "main" "master"; do
				if git -C "$script_workspace" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
					if git -C "$script_workspace" checkout "$branch" 2>/dev/null; then
						checkout_success=true
						echo "Successfully checked out branch: $branch"
						break
					fi
				fi
			done
		fi
		
		if [ "$checkout_success" = false ]; then
			echo "ERROR: Failed to recover from detached HEAD state."
			echo "Please delete $script_workspace and run setup again, or enable full_repo_refresh."
			exit 1
		fi
	fi
	
	# Use configured timeout value, default to 300 if not set
	GIT_TIMEOUT="${git_timeout:-300}"
	# Validate timeout is a positive integer
	if ! [[ "$GIT_TIMEOUT" =~ ^[0-9]+$ ]] || [ "$GIT_TIMEOUT" -lt 1 ]; then
		echo "ERROR: Invalid git_timeout value: $GIT_TIMEOUT (must be positive integer)"
		exit 1
	fi
	
	# Attempt to pull with timeout
	if timeout "$GIT_TIMEOUT" git -C "$script_workspace" pull; then
		echo "Repository updated successfully."
	else
		pull_exit_code=$?
		echo "WARNING: Failed to pull updates (exit code: $pull_exit_code). Keeping existing version."
		# Don't exit with error - we have a working version
		# But log this for monitoring
		LOG_DIR="/var/log/embedded-system-manager"
		if mkdir -p "$LOG_DIR" 2>/dev/null && [ -w "$LOG_DIR" ]; then
			echo "Git pull failed at $(date) with exit code $pull_exit_code" >> "$LOG_DIR/git.log" 2>/dev/null || true
		else
			echo "WARNING: Could not write to log file at $LOG_DIR/git.log"
		fi
		
		# If the repository is in a broken state, suggest recovery
		if ! git -C "$script_workspace" status >/dev/null 2>&1; then
			echo "ERROR: Repository appears to be in a broken state after failed pull."
			echo "Consider enabling full_repo_refresh or manually fixing the repository."
		fi
	fi
fi
