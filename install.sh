#!/bin/bash

confirm() {
  # $1 = prompt message
  while true; do
    read -r -p "$1 [y/N]: " response
    case "$response" in
      [yY][eE][sS]|[yY]) 
        return 0  # yes
        ;;
      [nN][oO]|[nN]|'') 
        return 1  # no or empty
        ;;
      *) 
        echo "Please answer yes or no."
        ;;
    esac
  done
}

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use: sudo $0)"
  exit 1
fi

# Detect package manager
if command -v apt-get >/dev/null 2>&1; then
  PKG_MGR="apt"
elif command -v dnf >/dev/null 2>&1; then
  PKG_MGR="dnf"
elif command -v yum >/dev/null 2>&1; then
  PKG_MGR="yum"
else
  echo "No supported package manager found (apt, dnf, yum). Exiting."
  exit 1
fi

# Wrapper functions
update_system() {
  if [ "$PKG_MGR" = "apt" ]; then
    apt-get update
    apt-get upgrade -y
  elif [ "$PKG_MGR" = "dnf" ]; then
    dnf makecache
    dnf upgrade -y
  else
    yum makecache
    yum update -y
  fi
}

install_packages() {
  # install all passed packages
  if [ "$PKG_MGR" = "apt" ]; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
  elif [ "$PKG_MGR" = "dnf" ]; then
    dnf install -y "$@"
  else
    yum install -y "$@"
  fi
}

echo "Welcome to the ktools install wizard!"
echo "Installation log files are written to /etc/ktools/ktools.log"
echo "Please only install and configure tools and packages if you know how they work and how they affect your system."
echo "It is recommended that you inspect the code of all tools prior to installation."
echo
echo -e "\033[1;33mWARNING: misconfiguring ktools can cause broken firewalls. Many system changes may be difficult to revert\033[0m"
echo
echo "Only install features you intend to use. Some features use nftables as the firewall, which breaks uncomplicated firewall (ufw)."
read -p "Press enter to acknowledge and continue with installation. Press CTRL+C at any time to exit."
clear

ktools_zip="./ktools.zip"

if [ ! -f "$ktools_zip" ]; then
  echo "ERROR: File '$ktools_zip' not found in the active directory."
  exit 1
fi

unzip_dir="/tmp/ktools_install_$$"
mkdir -p "$unzip_dir"
cleanup() {
  rm -rf "$unzip_dir"
}
trap cleanup EXIT

echo "Unzipping '$ktools_zip' to '$unzip_dir'..."
unzip -q "$ktools_zip" -d "$unzip_dir"
if [ $? -ne 0 ]; then
  echo "Failed to unzip $ktools_zip"
  exit 1
fi

cd "$unzip_dir/ktools" || { echo "Could not find extracted 'ktools' directory"; exit 1; }

mkdir -p /etc/ktools
touch /etc/ktools/ktools.conf
touch /etc/ktools/ktools.log

log() {
  echo "$1" >> /etc/ktools/ktools.log
}

clear

if confirm "Update/upgrade package lists? (may take a while and require reboot)"; then
  update_system
  log "updated/upgraded packages"
  clear
fi
clear

if confirm "Install auditd and configure with recommended rules?"; then
  # package name difference auditd (apt) vs audit (yum/dnf)
  if [ "$PKG_MGR" = "apt" ]; then
    install_packages auditd
  else
    install_packages audit
  fi

  systemctl start auditd
  systemctl enable auditd

  # Backup existing rules if any
  if [ -f /etc/audit/audit.rules ]; then
    cp /etc/audit/audit.rules /etc/audit/audit.rules.bak.$(date +%F-%T)
  fi

  # Write audit rules
  cat > /etc/audit/audit.rules <<EOF
# Delete all previous rules
-D

# Set buffer size
-b 8192

# Increase log format for more detail
-f 1

# Monitor changes to audit configuration
-w /etc/audit/audit.rules -p wa -k audit-configuration
-w /etc/audit/auditd.conf -p wa -k audit-configuration

# Monitor critical system binaries and config files
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# Monitor sudoers files
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers

# Monitor changes to PAM
-w /etc/pam.d/ -p wa -k pam

# Audit all execve syscalls (process executions)
-a exit,always -F arch=b64 -S execve -k exec
-a exit,always -F arch=b32 -S execve -k exec

# Audit all attempts to change system time
-a exit,always -F arch=b64 -S adjtimex -S settimeofday -S clock_settime -k time-change
-a exit,always -F arch=b32 -S adjtimex -S settimeofday -S clock_settime -k time-change

# Audit all login/logout events
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins

# Audit mounting and unmounting of filesystems
-a exit,always -F arch=b64 -S mount -S umount2 -k mounts
-a exit,always -F arch=b32 -S mount -S umount2 -k mounts

# Audit changes to network config files
-w /etc/hosts -p wa -k network
-w /etc/hostname -p wa -k network
-w /etc/network/ -p wa -k network

# Audit kernel module loading/unloading
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules

# Audit attempts to alter audit logs
-w /var/log/audit/ -p wa -k audit-logs

EOF

  systemctl restart auditd

  echo -e "\n\nAuditd installed and configured with default security-focused audit rules."
  echo "These rules cover key system files, commands, time changes, login events, and more."
  echo "Please review /etc/audit/audit.rules and customize as needed for your environment."
  read -r -p "Press enter to acknowledge"
  log "Installed and configured auditd with default rules"
  clear
fi
clear

if confirm "Install python?"; then
  if [ "$PKG_MGR" = "apt" ]; then
    install_packages python3 python3-pip
  else
    # Some RHEL-based distros may have python3-pip or python-pip
    if ! install_packages python3 python3-pip; then
      install_packages python3 python-pip
    fi
  fi
  clear
  if confirm "Install dependencies for ip list syncing?"; then
    pip3 install paho-mqtt
  fi
  clear
  log "Installed python3 and python packages: pip3, paho-mqtt"
fi
clear

echo "Install and configure ip lists and related custom tools/scripts?"
echo -e "\033[1;33mWARNING: This uses nftables and is not compatible with uncomplicated firewall (ufw)\033[0m"
if confirm "Continue?"; then
  install_packages nftables

  nft add table inet filter

  nft add set inet filter blacklist '{ type ipv4_addr; flags interval; }'
  nft add set inet filter whitelist '{ type ipv4_addr; flags interval; }'

  systemctl enable nftables
  systemctl start nftables

  install_packages mosquitto-clients

  cp ./blacklist.sh /bin/blacklist
  cp ./unblacklist.sh /bin/unblacklist
  cp ./whitelist.sh /bin/whitelist
  cp ./unwhitelist.sh /bin/unwhitelist
  chmod +x /bin/blacklist
  chmod +x /bin/unblacklist
  chmod +x /bin/whitelist
  chmod +x /bin/unwhitelist
  log "Installed ipset and custom ipset scripts"
  clear

  echo "Would you like to install mqtt server for ip list syncing?"
  echo -e "\033[1;33mWARNING: Only install on one machine\033[0m"
  if confirm "Continue?"; then
    install_packages mosquitto

    cat > "/etc/mosquitto/mosquitto.conf" <<EOF
# Listen on secure port
listener 8883

# TLS encryption
cafile /etc/mosquitto/certs/ca.crt
certfile /etc/mosquitto/certs/server.crt
keyfile /etc/mosquitto/certs/server.key

# Require clients to authenticate with certs (mTLS)
require_certificate false

# Only allow encrypted connections
allow_anonymous false
password_file /etc/mosquitto/passwd
EOF

    cat > "/etc/mosquitto/aclfile" <<EOF
user mosquitto-client
topic readwrite #
EOF
    read -p "At the next prompt, enter 'evening-conveyance-bill'. Press enter to continue"
    mosquitto_passwd /etc/mosquitto/passwd mosquitto-client

    mkdir -p /etc/mosquitto/certs
    cp ./ca.crt /etc/mosquitto/certs/ca.crt
    cp ./server.crt /etc/mosquitto/certs/server.crt
    cp ./server.key /etc/mosquitto/certs/server.key
    chmod 600 /etc/mosquitto/certs/server.key
    chown mosquitto: /etc/mosquitto/certs/server.key
    chmod 600 /etc/mosquitto/certs/server.crt
    chown mosquitto: /etc/mosquitto/certs/server.crt
    chmod 644 /etc/mosquitto/certs/ca.crt
    chown mosquitto: /etc/mosquitto/certs/ca.crt

    systemctl restart mosquitto
    log "Installed and configured mosquitto"
    clear
  fi
  clear

  echo "Install mosquitto client files?"
  echo -e "\033[1;33mWARNING: installing client modifies firewall rules\033[0m"
  echo -e "\033[1;33mWARNING: installing client requires python and ipset dependencies\033[0m"
  echo -e "\033[1;33mWARNING: client uses nftables and does not integrate with universal firewall (ufw)\033[0m"
  if confirm "Continue?"; then
    cp ./ca.crt /etc/ktools/ca.crt
    clear
    read -p "Enter ip of mqtt server or localhost if server is installed here: " mqtt_ip
    echo "mqtt_ip=$mqtt_ip" > /etc/ktools/ktools.conf
    clear
    cp ./ipsetsync.py /etc/ktools/ipsetsync.py
    cp ./ipsetsyncd.service /etc/systemd/system/ipsetsyncd.service
    systemctl daemon-reload
    systemctl enable ipsetsyncd.service
    systemctl start ipsetsyncd.service
    log "Installed mosquitto client data including ipsetsyncd.service"
    clear
  fi
fi

clear
echo -e "\033[1;33mWARNING: some services may require further configuration\033[0m"
echo -e "\033[1;33mWARNING: a reboot may be required to finalize some changes. A reboot can be triggered with 'sudo shutdown -r now'\033[0m"
echo -e "\033[1;33mWARNING: test all installed features immediately or directly after optional reboot\033[0m"
echo "ktools done."
exit 0

