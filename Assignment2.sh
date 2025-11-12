#!/bin/bash

# Define users who need standard access
STANDARD_USERS=(
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

# Define the SSH key for 'dennis'
DENNIS_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"
DENNIS_USER="dennis"
SUDO_GROUP="sudo"

echo "-----------------------------------------------------"
echo "Starting User Account and SSH Key Configuration..."
echo "-----------------------------------------------------"

# --- 1. Create DENNIS with SUDO access and SSH key setup ---
if id -u "$DENNIS_USER" >/dev/null 2>&1; then
    echo "User '$DENNIS_USER' already exists. Proceeding with configuration."
else
    echo "Creating user '$DENNIS_USER'..."
    # 1a. Create user without using the --disabled-password option.
    sudo useradd -m -s /bin/bash "$DENNIS_USER"
    
    # Check if creation was successful before locking the password
    if [ $? -eq 0 ]; then
        # 1b. Lock the password using 'passwd -l' for security (key-only access)
        echo "Locking password for '$DENNIS_USER' to enforce SSH key access."
        sudo passwd -l "$DENNIS_USER"
    else
        echo "ERROR: Failed to create user '$DENNIS_USER'. Aborting setup for this user."
        return 1 # Exit function early if user creation failed
    fi
fi

echo "Configuring '$DENNIS_USER' for sudo access (Group: $SUDO_GROUP)..."
# Add dennis to the sudo group for elevated privileges
# Use && to proceed only if the previous command (usermod) succeeded.
sudo usermod -aG "$SUDO_GROUP" "$DENNIS_USER" && \
echo "Groups for $DENNIS_USER: $(id -nG "$DENNIS_USER")"

echo "Configuring SSH key access for '$DENNIS_USER'..."
# Determine home directory safely
DENNIS_HOME=$(getent passwd "$DENNIS_USER" | cut -d: -f6)

SSH_DIR="$DENNIS_HOME/.ssh"
AUTH_KEYS_FILE="$SSH_DIR/authorized_keys"

# Create the .ssh directory and authorized_keys file
# The -p flag prevents errors if the directory already exists.
sudo mkdir -p "$SSH_DIR"
sudo touch "$AUTH_KEYS_FILE"

# Ensure the key is not duplicated before adding
if ! sudo grep -qF -- "$DENNIS_KEY" "$AUTH_KEYS_FILE"; then
    echo "$DENNIS_KEY" | sudo tee -a "$AUTH_KEYS_FILE" > /dev/null
    echo "Public key added to $AUTH_KEYS_FILE"
else
    echo "Public key is already present in $AUTH_KEYS_FILE"
fi

# Set ownership and permissions for the SSH files
# This step failed previously because the user 'dennis' didn't exist yet.
log_verbose "Setting ownership and permissions for $SSH_DIR." 
sudo chown -R "$DENNIS_USER":"$DENNIS_USER" "$SSH_DIR"
sudo chmod 700 "$SSH_DIR"
sudo chmod 600 "$AUTH_KEYS_FILE"

echo "'$DENNIS_USER' setup complete."
echo "-----------------------------------------------------"

# --- 2. Create Standard Users ---
echo " Creating standard user accounts (and locking passwords)..."

for user in "${STANDARD_USERS[@]}"; do
    if id -u "$user" >/dev/null 2>&1; then
        echo "   - User '$user' already exists. Skipping creation."
    else
        # 2a. Create user without using the --disabled-password option.
        if sudo useradd -m -s /bin/bash "$user"; then
            # 2b. Lock the password using 'passwd -l'
            sudo passwd -l "$user" > /dev/null 2>&1
            echo "   - User '$user' created and password locked."
        else
            echo "   - ERROR: Failed to create user '$user'."
        fi
    fi
done

echo "-----------------------------------------------------"
echo "Script execution complete."
echo "Note: All new accounts are configured for SSH access only (password locked)."
