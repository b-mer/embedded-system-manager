FROM debian:bookworm-slim

# Update repositories
RUN apt-get update

# Install python to run fake systemctl (this is not a dependency for the actual script, by the way, this is for testing)
RUN apt-get install -y python3

# Install whiptail for config setup (this should be already installed on most debian systems)
RUN apt-get install -y whiptail

# Install git so it can actually access the repository to clone
RUN apt-get install -y git

# Setting up a fake systemctl for testing
COPY systemctl3.py /usr/bin/systemctl
RUN chmod +x /usr/bin/systemctl
RUN mkdir -p /etc/systemd/system

# Setting up a fake journalctl for testing
COPY journalctl3.py /usr/bin/journalctl
RUN chmod +x /usr/bin/journalctl

# Copying the script over (really doesn't matter what directory it is in)
COPY . /home
WORKDIR /home
RUN chmod +x /home/setup.sh

CMD exec /home/setup.sh
