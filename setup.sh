#!/bin/bash

# Load env.
source .env

# Update OS
# Before running generic update. Lets sort out openssh interactive issue with debconf. So we will upgrade package to latest.
echo -e "\n 🟩  Updating system"
DEBIAN_FRONTEND=noninteractive apt-get install --only-upgrade openssh-server -y

apt update &&
apt upgrade -y &&

# GIT.
echo -e "\n 🟩  Installing GIT"
apt install git -y

echo -e "\n 🟩  Removing legacy filesystems"
echo "install freevxfs /bin/true" >> /etc/modprobe.d/blacklist.conf
echo "install jffs2 /bin/true" >> /etc/modprobe.d/blacklist.conf
echo "install hfs /bin/true" >> /etc/modprobe.d/blacklist.conf
echo "install hfsplus /bin/true" >> /etc/modprobe.d/blacklist.conf
echo "install squashfs /bin/true" >> /etc/modprobe.d/blacklist.conf
echo "install udf /bin/true" >> /etc/modprobe.d/blacklist.conf

# Avoids having to reboot to apply changes
echo -e "\n 🟩  Updating initramfs to reflect disabled filesystems"
update-initramfs -u

# Install CSI benchmark https://github.com/ovh/debian-cis
echo -e "\n 🟩  Fetching CIS benchmark"
git clone https://github.com/ovh/debian-cis.git && cd debian-cis

# Install dependencies
echo -e "\n 🟩  Setting up CIS benchmark"
cp debian/default /etc/default/cis-hardening
sed -i "s#CIS_LIB_DIR=.*#CIS_LIB_DIR='$(pwd)'/lib#" /etc/default/cis-hardening
sed -i "s#CIS_CHECKS_DIR=.*#CIS_CHECKS_DIR='$(pwd)'/bin/hardening#" /etc/default/cis-hardening
sed -i "s#CIS_CONF_DIR=.*#CIS_CONF_DIR='$(pwd)'/etc#" /etc/default/cis-hardening
sed -i "s#CIS_TMP_DIR=.*#CIS_TMP_DIR='$(pwd)'/tmp#" /etc/default/cis-hardening

# Create rule config and log
echo -e "\n 🟩  Starting CIS benchmark to generate hardening config files"
./bin/hardening.sh --audit-all

# Enable each config line by line to ensure nothing breaks.
# Ensire SSH cert setup before droplet created (rule: 99.5.2.1_)
echo -e "\n 🟩  Configuring which rules to enable"
sed -i 's/^status=[^ ]*/status=enabled/' etc/conf.d/*.cfg

# Disable specific configs
sed -i 's/^status=[^ ]*/status=disabled/' etc/conf.d/5.2.10_*.cfg
sed -i 's/^status=[^ ]*/status=disabled/' etc/conf.d/99.3.3.2_*.cfg
sed -i 's/^status=[^ ]*/status=disabled/' etc/conf.d/99.3.3.3_*.cfg

# Disable partition checks
sed -i 's/^status=[^ ]*/status=disabled/' etc/conf.d/1.1.*.cfg

# Disable unnecessary applications
sed -i 's/^status=[^ ]*/status=disabled/' etc/conf.d/2.2.*.cfg

# Start hardening
echo -e "\n 🟩  Applying hardening to OS"
./bin/hardening.sh --apply

# Log files
mkdir -p "$LOG_PATH_MODULES"

# Get errors for enabled configs only
echo -e "\n 🟩  Generating log files of CIS audit"
./bin/hardening.sh --audit --batch > $LOG_PATH_MODULES/audit.log

# Get failed configs
echo -e "\n 🟩  Generating list of rules that failed to apply"
grep "KO" log.txt > $LOG_PATH_MODULES/errors.log

## Setup unattended upgrades
echo -e "\n 🟩  Installing automated daily updates"
apt install -y unattended-upgrades apt-listchanges

# Settup unattended upgrades
echo -e "\n 🟩  Enabling unattended upgrades"
dpkg-reconfigure -f noninteractive unattended-upgrades

# Configuring automation
echo -e "\n 🟩  Configuring auto-upgrades"
cat <<EOF > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Daily timer is set at random to fetch latest lists for updates. Upgrader time runs the updates at random. This is to avoid all servers hitting the mirrors at the same time. 
# Reboot is immediate if required.
# Reboot will occur regarldless if users logged in. (!withUsers)
echo -e "\n 🟩  Configuring auto-upgrades schedule"
cat <<EOF > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=\${distro_codename},label=Debian-Security";
};
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "now";
EOF

# Setting up warning to users to logout.
echo -e "\n 🟩  Creating automatic reboot warning script"
tee "$WARNING_SCRIPT" > /dev/null << 'EOF'
#!/bin/bash

echo "\n ⚠️  System will reboot in 10 minutes for security updates. Save your work!  ⚠️" | wall
EOF

chmod +x "$WARNING_SCRIPT"

# Add cron job
echo -e "\n 🟩  Adding cron job"
CRON_FILE="/etc/crontab"
CRON_JOB="50 2 * * * root [ -f /var/run/reboot-required ] && $WARNING_SCRIPT"
if ! grep -qF "$WARNING_SCRIPT" "$CRON_FILE"; then
    echo "$CRON_JOB" | tee -a "$CRON_FILE" > /dev/null
    echo -e "\n ✅  Cron job added: Runs at 02:50 if a reboot is required."
else
    echo -e "\n ✅  Cron job already exists. No changes made."
fi

echo -e "\n 🟩  Restarting unattended-upgrades service"
systemctl restart unattended-upgrades

echo -e "\n 🟩  Testing security updates (dry-run)"
unattended-upgrades --dry-run --debug

## Generate SSH key pair only if it doesn't already exist.
echo -e "\n 🟩  Checking if SSH key pair already exists"

if [ ! -f ~/.ssh/id_rsa ]; then
    echo -e "\n 🟩  Generating new SSH key pair"
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
else
    echo -e "\n 🟩  SSH key pair already exists. Skipping generation."
fi

# Display public key
echo
echo -e "\n 🟩  Your SSH public key for the server"
echo
cat ~/.ssh/id_rsa.pub
echo

## Suggest reboot
echo -e "\n ✅  Hardening complete"

# Check if reboot is required. If file exists, reboot.
if [ -f /var/run/reboot-required ]; then echo -e "\n ⚠️  Reboot required  ⚠️"; fi
