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
if [ $(id -u) -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

# Run package upgrades
if [ $check_for_package_updates -eq 1 ]; then
    apt-get update && apt-get -y upgrade
else
    echo "check_for_package_updates flag disabled, skipping upgrade..."
fi

