Embedded System Manager
-----------------------

This is a script for Debian/Raspbian embedded systems that automatically runs code from a git repository on startup, included with tools to make the process much easier to manage.

DEPENDENCIES
------------

This script depends on systemd services at the moment.

SETUP & INSTALLATION
--------------------

- Set up SSH encryption keys (If your git repository is private).

- WIP

CONFIGURATION & DEBUGGING
-------------------------

If you run `edman`, you will be greeted with a list of command arguments.  
If you wish to change the `embedded-system-manager` config file, run: `sudo edman config` (or alternatively, `sudo edman configsetup` to run the setup again)  
If you wish to see the status of the systemd service for debugging purposes, run: `edman status`  
For live monitoring of the service, run: `edman output`  
If you want to restart the deployer service and refresh the script, run: `sudo edman reset`
