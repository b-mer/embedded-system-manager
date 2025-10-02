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
git clone https://github.com/b-mer/embedded-system-manager.git /tmp/embedded-system-manager

chmod +x /tmp/embedded-system-manager/setup.sh
source /tmp/embedded-system-manager/setup.sh
rm -rf /tmp/embedded-system-manager/
