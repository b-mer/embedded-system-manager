Embedded System Manager
-----------------------

This is a script for Debian/Raspbian embedded systems that automatically runs code from a git repository on startup, included with tools to make the process much easier to manage.  
It requires a network connection to run and the systemd service wont start until a network connection is activated.

DEPENDENCIES
------------

This script depends on systemd services at the moment.

SETUP & INSTALLATION
--------------------

- Set up SSH encryption keys (If your git repository is private).

- Run:
```bash
curl -sL https://raw.githubusercontent.com/b-mer/embedded-system-manager/main/install.sh | bash   
```

CONFIGURATION & DEBUGGING YOUR CODE
-----------------------------------

If you run `edman`, you will be greeted with a list of command arguments.  
If you wish to change the `embedded-system-manager` config file, run: `sudo edman config` (or alternatively, `sudo edman configsetup` to run the setup again)  
If you wish to see the status of the systemd service for debugging purposes, run: `edman status`  
For live monitoring of the service, run: `edman output`  
If you want to restart the deployer service and refresh the script, run: `sudo edman reset`

TESTING EMBEDDED SYSTEM MANAGER
-------------------------------

With docker installed, you can clone the repository and run `test_setup.sh` then run `setup.sh` inside the container's home directory to test and debug this project if you wish to modify it.  
`systemctl3.py` and `journalctl3.py` mimics systemd commands in the docker containers which this project would break without, and are from [docker-systemctl-replacement](https://github.com/gdraheim/docker-systemctl-replacement).
