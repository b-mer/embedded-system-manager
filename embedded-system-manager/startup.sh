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

# Ensure XDG_RUNTIME_DIR is set and exists for Wayland
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/embedded-system-manager}"
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
  mkdir -p "$XDG_RUNTIME_DIR"
  chmod 700 "$XDG_RUNTIME_DIR"
fi

# Run in location of script
cd "$(dirname "${BASH_SOURCE[0]}")"

# Check for required dependencies
echo "Checking for required dependencies..."
MISSING_DEPS=()

# Check for essential utilities
for cmd in "curl" "sha256sum" "timeout" "git" "dpkg" "apt-get" "systemctl"; do
  if ! command -v "$cmd" &> /dev/null; then
    MISSING_DEPS+=("$cmd")
  fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
  echo "ERROR: Missing required dependencies: ${MISSING_DEPS[*]}"
  echo "Please install the missing packages and try again."
  exit 1
fi

# Update mirrors before running package installs if needed

# Install if not exist function yoinked from stack exchange at https://codereview.stackexchange.com/questions/262937/installing-packages-if-they-dont-exist-in-bash
install_if_not_exist() {
  if command -v "$1" &>/dev/null; then
    return 0
  fi

  if dpkg -s "$1" &>/dev/null; then
    PKG_EXIST=$(dpkg -s "$1" | grep "install ok installed" || true)
    if [[ -n "$PKG_EXIST" ]]; then
      return 0
    fi
  fi

  echo "Package $1 missing. Updating package lists..."
  apt-get update --quiet || true

  if apt-get install "$1" -y -q; then
    return 0
  else
    echo "ERROR: Failed to install package: $1"
    return 1
  fi
}

# Clear all display managers and compositors to prepare for Cage takeover
# This function gracefully terminates X11 and Wayland sessions before forcing
clear_display_managers() {
  echo "--- STOPPING CONFLICTING DISPLAY MANAGERS ---"

  # Explicitly stop LightDM and Getty on TTY1 as they are common on Raspberry Pi
  systemctl stop lightdm 2>/dev/null || true
  systemctl stop getty@tty1.service 2>/dev/null || true
  
  # Stop all display manager services (more specific patterns to avoid false matches)
  systemctl list-units --type=service --state=running --no-pager --no-legend | \
    awk '{print $1}' | \
    (grep -E '^(gdm|lightdm|sddm|xdm|kdm|lxdm|slim|display-manager)\.service$' || true) | \
    while read -r service; do
      echo "Stopping $service..."
      systemctl stop "$service" 2>/dev/null || true
      systemctl disable "$service" 2>/dev/null || true
    done
  
  # Gracefully terminate X servers using DISPLAY protocol
  # Use find instead of ls for safer file enumeration
  if [ -d /tmp/.X11-unix ]; then
    (find /tmp/.X11-unix -maxdepth 1 -type s -name 'X*' 2>/dev/null || true) | while read -r socket; do
      display=$(basename "$socket" | sed 's/^X//')
      # Validate display is a number and not empty to prevent dangerous pattern matching
      if [ -n "$display" ] && [[ "$display" =~ ^[0-9]+$ ]] && [ "$display" -ge 0 ] && [ "$display" -le 99 ] 2>/dev/null; then
        echo "Gracefully terminating X server on DISPLAY :$display..."
        # Check if xdotool is available before using it
        if command -v xdotool &> /dev/null; then
          DISPLAY=:$display xdotool key --clearmodifiers Super_L+q 2>/dev/null || true
          sleep 1
        fi
        # Kill X server processes - use exact matching for safety
        # Additional validation: ensure display is still a safe number before using in pattern
        # Use literal display number instead of variable expansion in regex to prevent injection
        if [[ "$display" =~ ^[0-9]+$ ]]; then
          # Use pgrep to find PIDs first, then kill them - safer than pkill with patterns
          pgrep -f "^/usr/lib/xorg/Xorg.* :${display} " 2>/dev/null | xargs -r kill -15 2>/dev/null || true
          pgrep -f "^/usr/bin/X :${display} " 2>/dev/null | xargs -r kill -15 2>/dev/null || true
          sleep 3
          pgrep -f "^/usr/lib/xorg/Xorg.* :${display} " 2>/dev/null | xargs -r kill -9 2>/dev/null || true
          pgrep -f "^/usr/bin/X :${display} " 2>/dev/null | xargs -r kill -9 2>/dev/null || true
        fi
      fi
    done
  fi
  
  # Gracefully terminate Wayland compositors (more specific patterns)
  # Use find instead of ls for safer enumeration
  (find /run/user -maxdepth 2 -type s -name 'wayland-*' 2>/dev/null || true) | while read -r socket; do
    wayland_display=$(basename "$socket")
    if [ -n "$wayland_display" ] && [[ "$wayland_display" =~ ^wayland-[0-9]+$ ]]; then
      echo "Gracefully terminating Wayland compositor on $wayland_display..."
      # Check if wlr-randr is available before using it
      if command -v wlr-randr &> /dev/null; then
        WAYLAND_DISPLAY=$wayland_display wlr-randr --off 2>/dev/null || true
        sleep 1
      fi
    fi
  done
  
  # Send SIGTERM to specific Wayland compositor processes only
  for compositor in "weston" "mutter" "gnome-shell" "kwin_wayland" "sway"; do
    pkill -15 "$compositor" 2>/dev/null || true
  done
  sleep 2
  for compositor in "weston" "mutter" "gnome-shell" "kwin_wayland" "sway"; do
    pkill -9 "$compositor" 2>/dev/null || true
  done
  
  # Release DRM devices - check if any files exist first
  if [ -d /dev/dri ] && [ -n "$(ls -A /dev/dri 2>/dev/null)" ]; then
    echo "Releasing DRM devices..."
    fuser -k -15 /dev/dri/* 2>/dev/null || true
    sleep 1
    fuser -k -9 /dev/dri/* 2>/dev/null || true
  fi
  
  # Clear TTY1 for clean takeover - only if chvt is available
  if [ -e /dev/tty1 ] && command -v chvt &> /dev/null; then
    echo "Clearing TTY1..."
    if chvt 1 2>/dev/null; then
      sleep 1
    else
      echo "WARNING: Failed to switch to TTY1 (may be running headless or in container)"
    fi
  fi
}

# Validate configuration based on deployment type
validate_config() {
  echo "Validating configuration..."
  
  # Check deployment_source_type is set and valid
  if [ -z "$deployment_source_type" ]; then
    echo "ERROR: deployment_source_type is not set in config."
    return 1
  fi
  
  if [[ ! "$deployment_source_type" =~ ^(git|binary|package)$ ]]; then
    echo "ERROR: Invalid deployment_source_type: $deployment_source_type"
    echo "Valid options are: git, binary, package"
    return 1
  fi
  
  # Validate common settings
  if [ -z "$script_workspace" ]; then
    echo "ERROR: script_workspace is not set in config."
    return 1
  fi
  
  # Validate deployment-specific settings
  case "$deployment_source_type" in
    git)
      if [ -z "$repository_url" ]; then
        echo "ERROR: repository_url is required for git deployment."
        return 1
      fi
      if [ -z "$repo_run_command" ]; then
        echo "ERROR: repo_run_command is required for git deployment."
        return 1
      fi
      ;;
    binary)
      if [ -z "$binary_url" ]; then
        echo "ERROR: binary_url is required for binary deployment."
        return 1
      fi
      if [ -z "$binary_name" ]; then
        echo "ERROR: binary_name is required for binary deployment."
        return 1
      fi
      ;;
    package)
      if [ -z "$package_url" ]; then
        echo "ERROR: package_url is required for package deployment."
        return 1
      fi
      if [ -z "$package_run_command" ]; then
        echo "ERROR: package_run_command is required for package deployment."
        return 1
      fi
      ;;
  esac
  
  echo "Configuration validated successfully."
  return 0
}

# Load config file (basically works as a bash script in itself)
if ! source config; then
  echo "ERROR: Failed to load configuration file."
  exit 1
fi

# Clear display managers early if running in cage to ensure we own the TTY
if [ "${run_in_cage:-0}" -eq 1 ]; then
  clear_display_managers
fi

# Git is required for some deployments
install_if_not_exist git

# Load paths configuration if it exists
if [ -f paths.conf ]; then
  source paths.conf
fi

# Run validation immediately after loading config
if ! validate_config; then
  echo "ERROR: Configuration validation failed."
  exit 1
fi

# Validate numeric config values
echo "Validating numeric configuration values..."
if [ -n "${git_timeout:-}" ] && ! [[ "${git_timeout}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: git_timeout must be a positive integer, got: $git_timeout"
  exit 1
fi

if [ -n "${download_max_retries:-}" ] && ! [[ "${download_max_retries}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: download_max_retries must be a positive integer, got: $download_max_retries"
  exit 1
fi

if ! [[ "${run_in_cage:-0}" =~ ^[01]$ ]]; then
  echo "ERROR: run_in_cage must be 0 or 1, got: ${run_in_cage:-undefined}"
  exit 1
fi

if ! [[ "${run_script:-0}" =~ ^[01]$ ]]; then
  echo "ERROR: run_script must be 0 or 1, got: ${run_script:-undefined}"
  exit 1
fi

if ! [[ "${check_for_package_updates:-0}" =~ ^[01]$ ]]; then
  echo "ERROR: check_for_package_updates must be 0 or 1, got: ${check_for_package_updates:-undefined}"
  exit 1
fi

# Install the Cage wayland compositor if needed
if [ "$run_in_cage" -eq 1 ]; then
  echo "--- INSTALLING CAGE FOR KIOSK MODE ---"
  if ! install_if_not_exist cage; then
    echo "ERROR: Failed to install Cage window manager."
    exit 1
  fi
fi

echo "--- CHECKING FOR UPGRADES ---"

# Run package updates
source upgrade_packages.sh

echo "--- UPDATING DEPLOYMENT SOURCE ---"

# Route to appropriate installer based on deployment source type
case "$deployment_source_type" in
	git)
		echo "Using git repository deployment..."
		source install_repository.sh
		;;
	binary)
		echo "Using binary download deployment..."
		source install_binary.sh
		;;
	package)
		echo "Using package download deployment..."
		source install_package.sh
		;;
	*)
		echo "ERROR: Unknown deployment source type: $deployment_source_type"
		echo "Valid options are: git, binary, package"
		exit 1
		;;
esac

# If run script flag set to true, start the deployed program.
if [ "$run_script" -eq 1 ]; then
  echo "Startup complete, running program."
  
  # Determine the command to run based on deployment type
  case "$deployment_source_type" in
    git)
      cd "$script_workspace"

      # Check for wildcards to prevent multiple files being sourced/executed
      if [[ "$repo_run_command" == *"*"* ]]; then
        echo "ERROR: repo_run_command contains wildcards (*), which are not allowed: $repo_run_command"
        exit 1
      fi

      # Verify the file referenced in repo_run_command exists before attempting to source or execute it
      if [[ "$repo_run_command" =~ ^source\ + ]]; then
        # Extract the file path to be sourced
        REPO_FILE=$(echo "$repo_run_command" | awk '{print $2}')
        if [ ! -f "$REPO_FILE" ]; then
          echo "ERROR: Source file not found: $script_workspace/$REPO_FILE"
          exit 1
        fi
      elif [[ "$repo_run_command" =~ ^\./ ]] || [ -f "$(echo "$repo_run_command" | awk '{print $1}')" ]; then
        # Extract the file path to be executed
        REPO_FILE=$(echo "$repo_run_command" | awk '{print $1}')
        if [ ! -f "$REPO_FILE" ]; then
          echo "ERROR: File referenced in repo_run_command not found: $script_workspace/$REPO_FILE"
          exit 1
        fi
      fi

      RUN_COMMAND="$repo_run_command"
      ;;
    binary)
      cd "$script_workspace"
      # Validate binary exists before attempting to run
      if [ ! -f "$binary_name" ]; then
        echo "ERROR: Binary file not found: $script_workspace/$binary_name"
        exit 1
      fi
      if [ ! -x "$binary_name" ]; then
        echo "ERROR: Binary file is not executable: $script_workspace/$binary_name"
        exit 1
      fi
      RUN_COMMAND="./$binary_name $binary_run_flags"
      ;;
    package)
      # For packages, we don't change directory
      # Validate package command exists
      PACKAGE_CMD=$(echo "$package_run_command" | awk '{print $1}')
      if ! command -v "$PACKAGE_CMD" &> /dev/null; then
        echo "ERROR: Package command not found: $PACKAGE_CMD"
        echo "The package may not be installed correctly."
        exit 1
      fi
      RUN_COMMAND="$package_run_command"
      ;;
  esac
  
  # Validate RUN_COMMAND is not empty
  if [ -z "$RUN_COMMAND" ]; then
    echo "ERROR: No run command specified in configuration."
    exit 1
  fi
  
  # Check if we should run in Cage
  if [ "$run_in_cage" -eq 1 ]; then
    echo "Starting Cage Kiosk..."
    
    # Ensure DISPLAY is unset to avoid Wayland-X11 confusion
    unset DISPLAY

    # Graphics workarounds for Tauri on Raspberry Pi 5
    export GDK_BACKEND=wayland
    export GDK_CORE_DEVICE_EVENTS=1
    export GTK_CSD=0
    export GTK_OVERLAY_SCROLLING=0
    export GDK_GL=gles
    export WEBKIT_DISABLE_COMPOSITING_MODE=1
    export WEBKIT_USE_GLDOM=0
    export WEBKIT_DISABLE_DMABUF_RENDERER=1
    export WEBKIT_WEB_PROCESS_SANDBOX_STRICT=0

    if command -v gsettings &>/dev/null; then
      gsettings set org.gnome.desktop.wm.preferences button-layout '' || true
    fi
    
    # Run the program within Cage
    # Cage will run on the first available TTY
    if ! cage -- bash -c "$RUN_COMMAND"; then
      echo "ERROR: Failed to execute command in Cage: $RUN_COMMAND"
      exit 1
    fi
  else
    # Run normally without Cage - use bash -c instead of eval for safety
    if ! bash -c "$RUN_COMMAND"; then
      echo "ERROR: Failed to execute run command: $RUN_COMMAND"
      exit 1
    fi
  fi
  
  cd /opt/embedded-system-manager
else
  echo "Startup complete."
fi
