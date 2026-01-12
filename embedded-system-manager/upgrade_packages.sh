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

# Run package upgrades
if [ "$check_for_package_updates" -eq 1 ]; then
    echo "Updating package lists..."
    LOG_DIR="/var/log/embedded-system-manager"
    
    if apt-get update; then
        echo "Upgrading packages..."
        if apt-get -y upgrade; then
            echo "Package upgrade completed successfully."
        else
            echo "WARNING: Package upgrade failed. Continuing anyway..."
            # Log the failure for monitoring
            if mkdir -p "$LOG_DIR" 2>/dev/null && [ -w "$LOG_DIR" ]; then
                echo "Package upgrade failed at $(date)" >> "$LOG_DIR/updates.log" 2>/dev/null || true
            else
                echo "WARNING: Could not write to log file at $LOG_DIR/updates.log"
            fi
        fi
    else
        echo "WARNING: Failed to update package lists. Skipping upgrade..."
        # Log the failure for monitoring
        if mkdir -p "$LOG_DIR" 2>/dev/null && [ -w "$LOG_DIR" ]; then
            echo "Package list update failed at $(date)" >> "$LOG_DIR/updates.log" 2>/dev/null || true
        else
            echo "WARNING: Could not write to log file at $LOG_DIR/updates.log"
        fi
    fi
else
    echo "check_for_package_updates flag disabled, skipping upgrade..."
fi
