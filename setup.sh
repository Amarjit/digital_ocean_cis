#!/bin/bash

# Update OS
# Before running generic update. Lets sort out openssh interactive issue with debconf. So we will upgrade package to latest.
echo -e "\nUpdating system..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install --only-upgrade openssh-server -y

sudo apt update &&
sudo apt upgrade -y &&

# GIT.
echo -e "\nInstalling GIT..."
sudo apt install git -y

echo -e "\nRemoving legacy filesystems..."
echo "install freevxfs /bin/true" >> /etc/modprobe.d/blacklist.conf
echo "install jffs2 /bin/true" >> /etc/modprobe.d/blacklist.conf
echo "install hfs /bin/true" >> /etc/modprobe.d/blacklist.conf
echo "install hfsplus /bin/true" >> /etc/modprobe.d/blacklist.conf
echo "install squashfs /bin/true" >> /etc/modprobe.d/blacklist.conf
echo "install udf /bin/true" >> /etc/modprobe.d/blacklist.conf

# Avoids having to reboot to apply changes
echo -e "\nUpdating initramfs to reflect disabled filesystems..."
sudo update-initramfs -u

# Install CSI benchmark https://github.com/ovh/debian-cis
echo -e "\nFetching CIS benchmark..."
git clone https://github.com/ovh/debian-cis.git && cd debian-cis

# Install dependencies
echo -e "\nSetting up CIS benchmark..."
cp debian/default /etc/default/cis-hardening
sed -i "s#CIS_LIB_DIR=.*#CIS_LIB_DIR='$(pwd)'/lib#" /etc/default/cis-hardening
sed -i "s#CIS_CHECKS_DIR=.*#CIS_CHECKS_DIR='$(pwd)'/bin/hardening#" /etc/default/cis-hardening
sed -i "s#CIS_CONF_DIR=.*#CIS_CONF_DIR='$(pwd)'/etc#" /etc/default/cis-hardening
sed -i "s#CIS_TMP_DIR=.*#CIS_TMP_DIR='$(pwd)'/tmp#" /etc/default/cis-hardening

# Create rule config and log
echo -e "\nStarting CIS benchmark to generate hardening config files..."
./bin/hardening.sh --audit-all

# Enable each config line by line to ensure nothing breaks.
# Ensire SSH cert setup before droplet created (rule: 99.5.2.1_)
echo -e "\nConfiguring which rules to enable..."
sudo sed -i 's/^status=[^ ]*/status=enabled/' etc/conf.d/*.cfg

# Disable specific configs
sudo sed -i 's/^status=[^ ]*/status=disabled/' etc/conf.d/5.2.10_*.cfg
sudo sed -i 's/^status=[^ ]*/status=disabled/' etc/conf.d/99.3.3.2_*.cfg
sudo sed -i 's/^status=[^ ]*/status=disabled/' etc/conf.d/99.3.3.3_*.cfg

# Disable partition checks
sudo sed -i 's/^status=[^ ]*/status=disabled/' etc/conf.d/1.1.*.cfg

# Disable unnecessary applications
sudo sed -i 's/^status=[^ ]*/status=disabled/' etc/conf.d/2.2.*.cfg

# Start hardening
echo -e "\nApplying hardening to OS..."
./bin/hardening.sh --apply

# Get errors for enabled configs only
echo -e "\nGenering log files of CIS audit (log.txt)..."
./bin/hardening.sh --audit --batch > log.txt

# Get failed configs
echo -e "\nGenerating list of rules that failed to apply (failed.txt)..."
grep "KO" log.txt > failed.txt

# Suggest reboot
echo -e "\nHardening complete."
