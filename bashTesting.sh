#!/bin/bash

# --- Configuration Variables ---
TARGET_IP="192.168.16.21"
TARGET_CIDR="24"
TARGET_NETPLAN_CONFIG="/etc/netplan/00-installer-config.yaml" # Common default file
HOSTS_FILE="/etc/hosts"
SERVER_HOSTNAME="server1"

# List of users to create
USER_LIST=(
    "dennis"
    "aubrey"
    "captain"
    "snibbles"
    "brownie"
    "scooter"
    "sandy"
    "perrier"
    "cindy"
    "tiger"
    "yoda"
)

# Public key for 'dennis'
DENNIS_EXTRA_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "⚠️ Please run as root (e.g., sudo ./configure_server.sh)"
    exit 1
fi

echo "--- Starting Server Configuration Script ---"

# --- 1. Network Interface Configuration (Netplan) ---
echo "## 1. Configuring Netplan for ${TARGET_IP}/${TARGET_CIDR}"

# Find the interface to configure:
# We look for the interface that currently has a 192.168.16.x address.
# The script will only modify the configuration block for the identified interface.

# Step 1.1: Identify the target interface name.
TARGET_INTERFACE=""
# Use `ip addr` output to find an interface in the 192.168.16.0/24 range
# and ignore 'lo' (loopback).
TARGET_INTERFACE=$(ip -4 addr show | grep -B 1 "inet 192.168.16." | head -n 1 | awk '{print $2}' | tr -d ':')

if [ -z "$TARGET_INTERFACE" ]; then
    echo "❌ Could not automatically find the interface attached to the 192.168.16.0/24 network. Exiting."
    echo "Please manually inspect your netplan file and set the TARGET_INTERFACE variable."
    exit 1
fi

echo "✅ Target interface identified as: **${TARGET_INTERFACE}**"

# Step 1.2: Modify the Netplan configuration file.
if [ ! -f "$TARGET_NETPLAN_CONFIG" ]; then
    echo "❌ Netplan configuration file not found at $TARGET_NETPLAN_CONFIG. Exiting."
    exit 1
fi

echo "   -> Updating ${TARGET_NETPLAN_CONFIG}..."

# We use a temporary file for safe editing and assume a standard YAML structure.
# This sed block removes the old configuration for the interface and inserts the new static one.

sed -i "/${TARGET_INTERFACE}:/,/^ *[^[:space:]]/ {
    /renderer:/!{
        /addresses:/!{
            /dhcp4:/!{
                /optional:/!{
                    /match:/!{
                        /set-name:/!{
                            /name:/!d
                        }
                    }
                }
            }
        }
    }
}" "$TARGET_NETPLAN_CONFIG"

# Insert the new static configuration block.
# Assuming 'ethernets' section already exists.
sed -i "/ethernets:/a \ \ ${TARGET_INTERFACE}: \
\ \ \ \ dhcp4: no \
\ \ \ \ addresses: [${TARGET_IP}/${TARGET_CIDR}]" "$TARGET_NETPLAN_CONFIG"

# Step 1.3: Apply the new Netplan configuration.
echo "   -> Applying new Netplan configuration..."
netplan apply

echo "✅ Network configuration updated and applied."

# --- 2. Hostname Resolution Configuration (/etc/hosts) ---
echo "## 2. Configuring ${HOSTS_FILE} for ${SERVER_HOSTNAME}"

# Remove any existing entry for the hostname 'server1' (IP on the line is irrelevant for the search)
sed -i "/${SERVER_HOSTNAME}/d" $HOSTS_FILE

# Add the new, correct entry
echo "${TARGET_IP}    ${SERVER_HOSTNAME}" >> $HOSTS_FILE

echo "✅ Hostname resolution configured."

# --- 3. Software Installation and Configuration ---
echo "## 3. Installing apache2 and squid"

# Ensure package lists are up to date
apt update -y

# Install packages
apt install -y apache2 squid

# Enable and start services (if not already done by apt)
systemctl enable apache2 squid
systemctl start apache2 squid

echo "✅ apache2 and squid installed and running in default configuration."

# --- 4. User Accounts and SSH Key Management ---
echo "## 4. Creating User Accounts and SSH Keys"

for user in "${USER_LIST[@]}"; do
    echo "   -> Processing user: **${user}**"

    # 4.1 Create user with home directory and bash shell
    if id "$user" &>/dev/null; then
        echo "      -> User already exists. Skipping useradd."
    else
        useradd -m -s /bin/bash "$user"
        echo "      -> User created."
    fi

    # 4.2 Grant sudo access if user is 'dennis'
    if [ "$user" == "dennis" ]; then
        usermod -aG sudo "$user"
        echo "      -> **SUDO access granted.**"
    fi

    # 4.3 SSH Key Generation and Setup
    HOME_DIR="/home/${user}"
    SSH_DIR="${HOME_DIR}/.ssh"
    AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

    # Create .ssh directory and set permissions
    mkdir -p "$SSH_DIR"
    chown "$user":"$user" "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    # Clear previous authorized_keys to ensure clean setup
    > "$AUTHORIZED_KEYS"
    chown "$user":"$user" "$AUTHORIZED_KEYS"
    chmod 600 "$AUTHORIZED_KEYS"

    # Generate RSA Key
    echo "      -> Generating RSA key for $user..."
    ssh-keygen -t rsa -N "" -f "${SSH_DIR}/id_rsa" <<<y >/dev/null 2>&1
    cat "${SSH_DIR}/id_rsa.pub" >> "$AUTHORIZED_KEYS"

    # Generate ED25519 Key
    echo "      -> Generating ED25519 key for $user..."
    ssh-keygen -t ed25519 -N "" -f "${SSH_DIR}/id_ed25519" <<<y >/dev/null 2>&1
    cat "${SSH_DIR}/id_ed25519.pub" >> "$AUTHORIZED_KEYS"

    # 4.4 Add 'dennis' specific public key
    if [ "$user" == "dennis" ]; then
        echo "      -> Adding external public key for dennis..."
        echo "$DENNIS_EXTRA_KEY" >> "$AUTHORIZED_KEYS"
    fi
    
    echo "      -> Keys generated and added to authorized_keys."

done

echo "✅ All user accounts and SSH keys configured."

echo "--- Server Configuration Complete! ---"
echo "Server IP: ${TARGET_IP}"
echo "Hostname: ${SERVER_HOSTNAME}"
echo "Web Server: apache2"
echo "Proxy: squid"
