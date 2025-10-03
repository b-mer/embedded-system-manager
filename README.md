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
  - NOTE: Encryption keys with passwords aren't supported at the moment

- Run:
```bash
bash -c "$(curl -sL https://raw.githubusercontent.com/b-mer/embedded-system-manager/main/install.sh)"
```

CAGE KIOSK MODE
---------------

Embedded System Manager can run your code in [Cage](https://github.com/cage-kiosk/cage). This allows you to have a kiosk setup.

NOTE: With cage mode enabled, the script automatically handles display conflicts by stopping any existing display managers or window systems before launching.

To enable Cage mode, select "Yes" when prompted during setup, or manually set `run_in_cage=1` in the config file.

### CAGE AND TTY SESSIONS

When Cage is running on TTY1, you can still access other virtual terminals for system administration or debugging.

To switch to a different TTY:
- Press Ctrl+Alt+F2 for TTY2
- Press Ctrl+Alt+F3 for TTY3
- etc.

To return to the Cage kiosk on TTY1:
- Press Ctrl+Alt+F1

You can log in normally on these other TTYs or use SSH to access the system remotely. The Cage kiosk should continue running independently on TTY1.

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
