Embedded System Manager
-----------------------

This is a script for Debian/Raspbian embedded systems that automatically deploys and runs code on startup, with support for multiple deployment sources:
- **Git repositories** - Clone/pull from any git repository
- **Binary downloads** - Download and run standalone binaries
- **Package installation** - Install .deb packages

It requires a network connection to run and the systemd service won't start until a network connection is activated.  

NOTE: This is still an experimental tool and may need some improvements

DEPENDENCIES
------------

This script depends on systemd services at the moment, and will automatically install `git` and `whiptail` if it can't be found.

SETUP & INSTALLATION
--------------------

- Set up SSH encryption keys if you are using a private git repository.
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

DEPLOYMENT SOURCE TYPES
------------------------

During setup, you'll be asked to choose a deployment source type:

### Git Repository
Clone and pull code from a git repository. Supports:
- Public and private repositories (with SSH keys)
- Branch selection
- Full refresh or incremental pull updates
- Automatic rollback on pull failures

### Binary Download
Download a standalone binary file. Supports:
- Direct URL downloads
- SHA256 checksum verification
- Bearer token or basic authentication
- Automatic executable permissions
- Update on each boot or download once
- Rollback protection (keeps previous version on download failure)

### Package Installation
Install .deb packages. Supports:
- Direct URL downloads of .deb files
- SHA256 checksum verification
- Bearer token or basic authentication
- Automatic dependency resolution
- Update on each boot or install once
- Rollback protection (keeps previous installation on failure)

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

There is also a test repository you can use this on: [embedded-system-manager-test-repo](https://github.com/b-mer/embedded-system-manager-test-repo) (works with the default config for the repository run command).  
Git URL: `https://github.com/b-mer/embedded-system-manager-test-repo.git`
