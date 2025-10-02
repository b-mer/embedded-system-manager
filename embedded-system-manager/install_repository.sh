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

if [ $full_repo_refresh -eq 1 ]; then
	# Checks if script directory exists, if so, delete it to clear any older versions of the script
	if [ -d $script_workspace ]; then
		rm -rf $script_workspace
	fi

	# Make a new folder for the script
	mkdir $script_workspace

	# Clone repository into script directory
	if [[ "$repository_branch" == "" ]]; then
		git clone $repository_url $script_workspace
	else
		git clone --branch $repository_branch $repository_url $script_workspace
	fi

	# Set executable permission for main file
	chmod +x $script_workspace/main.*
else
	git -C $script_workspace pull
fi
