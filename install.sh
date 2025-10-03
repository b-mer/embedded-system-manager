#!/bin/bash
set -euo pipefail

# Cleanup function
cleanup() {
  if [ -d /tmp/embedded-system-manager ]; then
    rm -rf /tmp/embedded-system-manager
  fi
}

# Set trap to cleanup on exit or error
trap cleanup EXIT INT TERM

# Check if whiptail is installed.
if ! command -v whiptail &> /dev/null; then
  echo "Error: whiptail is not installed." >&2
  exit 1
fi
# Check if git is installed.
if ! command -v git &> /dev/null; then
  echo "Error: git is not installed." >&2
  exit 1
fi

echo "Cloning repository into /tmp/embedded-system-manager..."
rm -rf /tmp/embedded-system-manager   
if ! git clone https://github.com/b-mer/embedded-system-manager.git /tmp/embedded-system-manager; then
  echo "ERROR: Failed to clone repository." >&2
  exit 1
fi

chmod +x /tmp/embedded-system-manager/setup.sh
if ! bash /tmp/embedded-system-manager/setup.sh; then
  echo "ERROR: Setup script failed." >&2
  exit 1
fi
