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

# Run in location of script
cd "$(dirname "$BASH_SOURCE")"   

# Update mirrors before running package installs
apt-get update

# Install if not exist function yoinked from stack exchange at https://codereview.stackexchange.com/questions/262937/installing-packages-if-they-dont-exist-in-bash
install_if_not_exist() {
  if dpkg -s "$1" &>/dev/null; then
    PKG_EXIST=$(dpkg -s "$1" | grep "install ok installed")
    if [[ -n "$PKG_EXIST" ]]; then
      return
    fi
  fi
  apt-get install "$1" -y
}

# Clear all display managers and compositors to prepare for Cage takeover
# This function gracefully terminates X11 and Wayland sessions before forcing
clear_display_managers() {
  echo "--- STOPPING CONFLICTING DISPLAY MANAGERS ---"
  
  # Stop all display manager services (more specific patterns to avoid false matches)
  systemctl list-units --type=service --state=running --no-pager --no-legend | \
    awk '{print $1}' | \
    grep -E '^(gdm|lightdm|sddm|xdm|kdm|lxdm|slim)\.service$|^display-manager\.service$' | \
    while read -r service; do
      echo "Stopping $service..."
      systemctl stop "$service" 2>/dev/null || true
      systemctl disable "$service" 2>/dev/null || true
    done
  
  # Gracefully terminate X servers using DISPLAY protocol
  for display in $(ls /tmp/.X11-unix/* 2>/dev/null | sed 's|/tmp/.X11-unix/X||'); do
    if [ -n "$display" ] && [ "$display" -ge 0 ] 2>/dev/null; then
      echo "Gracefully terminating X server on DISPLAY :$display..."
      DISPLAY=:$display xdotool key --clearmodifiers Super_L+q 2>/dev/null || true
      sleep 0.5
      # More specific pattern to avoid killing unrelated processes
      pkill -15 -f "^/usr/lib/xorg/Xorg.*:$display" 2>/dev/null || true
      pkill -15 -f "^X :$display" 2>/dev/null || true
      sleep 1
      pkill -9 -f "^/usr/lib/xorg/Xorg.*:$display" 2>/dev/null || true
      pkill -9 -f "^X :$display" 2>/dev/null || true
    fi
  done
  
  # Gracefully terminate Wayland compositors (more specific patterns)
  for wayland_display in $(ls /run/user/*/wayland-* 2>/dev/null | grep -o 'wayland-[0-9]*'); do
    if [ -n "$wayland_display" ]; then
      echo "Gracefully terminating Wayland compositor on $wayland_display..."
      WAYLAND_DISPLAY=$wayland_display wlr-randr --off 2>/dev/null || true
      sleep 0.5
    fi
  done
  
  # Send SIGTERM to specific Wayland compositor processes only
  for compositor in weston mutter gnome-shell kwin_wayland sway; do
    pkill -15 "^$compositor$" 2>/dev/null || true
  done
  sleep 1
  for compositor in weston mutter gnome-shell kwin_wayland sway; do
    pkill -9 "^$compositor$" 2>/dev/null || true
  done
  
  # Release DRM devices
  if [ -d /dev/dri ]; then
    echo "Releasing DRM devices..."
    fuser -k -15 /dev/dri/* 2>/dev/null || true
    sleep 1
    fuser -k -9 /dev/dri/* 2>/dev/null || true
  fi
  
  # Clear TTY1 for clean takeover
  if [ -e /dev/tty1 ]; then
    echo "Clearing TTY1..."
    chvt 1 2>/dev/null || true
    sleep 1
  fi
}

install_if_not_exist git

# Load config file (basically works as a bash script in itself)
source config

# Install the Cage wayland compositor if needed
if [ $run_in_cage -eq 1 ]; then
  echo "--- INSTALLING CAGE FOR KIOSK MODE ---"
  install_if_not_exist cage
  install_if_not_exist wlroots
  
  # Clear any existing display managers/compositors
  clear_display_managers
fi

echo "--- CHECKING FOR UPGRADES ---"

# Run package updates
source upgrade_packages.sh

echo "--- UPDATING DEPLOYMENT SOURCE ---"

# Route to appropriate installer based on deployment source type
case "$deployment_source_type" in
	git)
		echo "Using git repository deployment..."
		. install_repository.sh
		;;
	binary)
		echo "Using binary download deployment..."
		. install_binary.sh
		;;
	package)
		echo "Using package download deployment..."
		. install_package.sh
		;;
	*)
		echo "ERROR: Unknown deployment source type: $deployment_source_type"
		echo "Valid options are: git, binary, package"
		exit 1
		;;
esac

# If run script flag set to true, start the deployed program.
if [ $run_script -eq 1 ]; then
  echo "Startup complete, running program."
  
  # Determine the command to run based on deployment type
  case "$deployment_source_type" in
    git)
      cd "$script_workspace"
      RUN_COMMAND="$repo_run_command"
      ;;
    binary)
      cd "$script_workspace"
      RUN_COMMAND="./$binary_name $binary_run_flags"
      ;;
    package)
      # For packages, we don't change directory
      RUN_COMMAND="$package_run_command"
      ;;
  esac
  
  # Check if we should run in Cage
  if [ $run_in_cage -eq 1 ]; then
    echo "Starting Cage Kiosk..."
    # Run the program within Cage
    # Cage will run on the first available TTY
    cage -- bash -c "$RUN_COMMAND"
  else
    # Run normally without Cage
    eval "$RUN_COMMAND"
  fi
  
  cd /opt/embedded-system-manager
else
  echo "Startup complete."
fi
