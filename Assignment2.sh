#!/bin/bash

###############################################################################
#                           ASSIGNMENT 2 - SYSTEM SETUP                       #
#                       	  RIKEN PATEL  200625801     					  #
###############################################################################

: <<'COMMENT'
PLAN FOR SECTION 1
CHECK FOR FOLDERS EXISTENCE
IF NOT ==> CREATE AND ADD DEFAULT LINUX CONFIGS

WHEN WORKING WITH NETPLAN FILES
IF THERE IS NONE ==> CREATE AND ADD DEFAULT
IF ONE ==> EDIT
IF MULTIPLE ==> MAKE ALL THOSE FILES AS .bak AND CREATE NEW WITH DEFAULT CONFIGS

PLAN FOR SECTION 2
CHECK IF REQUIRED PACKAGES EXIST
IF NOT ==> INSTALL (apache2, squid)

IF PACKAGE EXISTS ==> CHECK IF UP TO DATE
IF NOT SHOW WARNING ==> DO NOT FORCE UPDATE PACKAGES

START SERVICES WITH DEFAULT CONFIGS
COMMENT

# -------------------------------
# Start live runtime timer
# -------------------------------
startLiveTimer() {
    SECONDS=0
    DOTS=""
    LONG_TASK=false

    (
        while true; do
            elapsed=$SECONDS
            if [ "$LONG_TASK" = true ]; then
                # Rotate dots every second
                case $((elapsed % 4)) in
                    0) DOTS="";;
                    1) DOTS="."; 
                    2) DOTS=".."; 
                    3) DOTS="...";;
                esac
            fi

            printf "\rScript runtime: %02d:%02d:%02d%s" \
                $((elapsed/3600)) $(((elapsed/60)%60)) $((elapsed%60)) "$DOTS"
            sleep 1
        done
    ) &
    TIMER_PID=$!
}

stopLiveTimer() {
    kill "$TIMER_PID" 2>/dev/null
    wait "$TIMER_PID" 2>/dev/null
    echo -e "\nScript finished!"
}

# -------------------------------
# task with long-feedback
# -------------------------------
runTask() {
    local duration=$1   # Task simulated duration in seconds
    LONG_TASK=false

    # If task is longer than threshold, enable dots
    THRESHOLD=5
    ( sleep "$THRESHOLD"; LONG_TASK=true ) &  # Start background timer for dots
    THRESHOLD_PID=$!

    # Simulate the task
    sleep "$duration"

    # Task done, stop dots timer
    LONG_TASK=false
    kill "$THRESHOLD_PID" 2>/dev/null
    wait "$THRESHOLD_PID" 2>/dev/null
}


stopLiveTimer() {
    kill "$TIMER_PID" 2>/dev/null
    wait "$TIMER_PID" 2>/dev/null
    echo -e "\nScript finished!"
}


#     LOG & ERROR FILE SETUP    
errorFile="scriptErrorFile"
logFile="scriptLogFile"

[ -f "$errorFile" ] || touch "$errorFile"    # Creates error file if missing
[ -f "$logFile" ]  || touch "$logFile"       # Creates log file if missing

echo "INFO: Log and error files for more info: $logFile, $errorFile" | tee -a "$logFile"
echo "---------------------------   $date   ---------------------------------" >> $logFile
echo "---------------------------   $date   ---------------------------------" >> $errorFile
#     PRE-CHECK: NETPLAN DIR
if [ ! -d /etc/netplan ]; then                  # Checks netplan directory
    sudo mkdir -p /etc/netplan 2>>"$errorFile"  # Creates directory if missing
    if [ $? -eq 0 ]; then
        echo "INFO: NETPLAN DIRECTORY EXISTS NOW" | tee -a "$logFile"         # Confirms creation
    else
        echo "ERROR: NETPLAN DIRECTORY CREATION FAILS" | tee -a "$errorFile"
    fi
fi

netplanFiles="$(ls /etc/netplan/ 2>/dev/null)"                # Lists netplan files
newNetplanFile="/etc/netplan/$(date +%Y-%m-%d)-netplan.yaml"  #  new netplan file

# CREATE NEW NETPLAN FILE
createNetplanFile() {
    newNetplanFile="/etc/netplan/$(date +%Y-%m-%d)-netplan.yaml"

    # If file already exists, skip to avoid duplication
    if [ -f "$newNetplanFile" ]; then
        echo "[SKIP] Netplan file already exists: $newNetplanFile"
        return 0
    fi

    echo "[INFO] Creating new netplan file: $newNetplanFile"

    sudo bash -c "cat << 'EOF' > \"$newNetplanFile\"
network:
    version: 2
    ethernets:
        eth0:
            addresses: [192.168.16.21/24]
            routes:
              - to: default
                via: 192.168.16.2
            nameservers:
                addresses: [192.168.16.2]
                search: [home.arpa, localdomain]
        eth1:
            addresses: [172.16.1.242/24]
EOF"

    echo "[INFO] Netplan file created."

    # Validate syntax
    echo "[INFO] Validating netplan configuration..."
    if sudo netplan try --timeout 5; then
        echo "[SUCCESS] Netplan configuration is valid!"
		sudo netplan apply
    else
        echo "[ERROR] Netplan validation failed!"
    fi
}


    echo "INFO: New netplan file exists at $newNetplanFile" | tee -a "$logFile"
    echo "INFO: Applying netplan now..." | tee -a "$logFile"  
    sudo netplan apply >>"$logFile" 2>>"$errorFile" 
    if [ $? -eq 0 ]; then
        echo "INFO: Netplan applies successfully" | tee -a "$logFile"
    else
        echo "ERROR: Netplan application fails" | tee -a "$errorFile"
    fi
}

# APPLY NETPLAN CONFIG
netplanApply() {
    echo "INFO: Applying netplan configuration..." | tee -a "$logFile"  
    if sudo netplan apply >>"$logFile" 2>>"$errorFile"; then  # Applies netplan
        echo "INFO: Netplan applies successfully. IP: $(ip -o -4 addr show | awk '/192.168.16.21/ {print $2, $4}')" | tee -a "$logFile"  # Prints IP
    else
        echo "ERROR: Netplan fails to apply" | tee -a "$errorFile"  
    fi
}

# EDIT EXISTING NETPLAN
netplanChange() {
    echo "INFO: Starting netplan change process..." | tee -a "$logFile"  

    netplanFiles=(/etc/netplan/*.yaml)        # Creates array of netplan files
    fileCount=${#netplanFiles[@]}             # Counts files

    if [ $fileCount -eq 0 ]; then             # Checks if no files
        echo "INFO: No netplan files found, creating new one." | tee -a "$logFile"  
        newNetplan                               # Calls newNetplan
    elif [ $fileCount -eq 1 ]; then              # Checks if single file
        echo "INFO: Found single netplan file: ${netplanFiles[0]}" | tee -a "$logFile"  # Prints file
        for file in "${netplanFiles[@]}"; do
            sudo sed -i -E "s#(192\.168\.16\.)[0-9]{1,3}(/24)#\121\2#g" "$file"    # Updates IP
            echo "INFO: Updates IP in $file to 192.168.16.21" | tee -a "$logFile"  # Logs update
        done
        netplanApply                               # Calls netplanApply
        [ "${netplanFiles[0]}" != "$newNetplanFile" ] && sudo mv "${netplanFiles[0]}" "$newNetplanFile" && echo "INFO: Renames netplan file to $newNetplanFile" | tee -a "$logFile"  # Renames file
    else  # Handles multiple files
        echo "INFO: Multiple netplan files found, backup and create new..." | tee -a "$logFile"
        for file in "${netplanFiles[@]}"; do
            sudo mv "$file" "${file}.bak"      # Backs up each file
            echo "INFO: Backs up $file -> ${file}.bak" | tee -a "$logFile"  # Logs backup
        done
        newNetplan  # Calling function
    fi
}

# EDIT /etc/hosts FILE                           
editingHostsFile() {
    hostsFile="/etc/hosts"    # Sets hosts file path

    if [ ! -f "$hostsFile" ]; then  # Checks if hosts file missing
        echo "INFO: Creating /etc/hosts with defaults..." | tee -a "$logFile"  
cat << EOF > $hostsFile
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters

192.168.16.21 server2
172.16.1.242 server2-mgmt
192.168.16.21 openwrt
172.16.1.2 openwrt-mgmt
EOF
        sudo chmod 644 "$hostsFile"    # Sets permissions -rw-r--r--
    fi

    echo "INFO: Updating /etc/hosts IPs..." | tee -a "$logFile"  
    sudo sed -i -E 's/192\.168\.16\.[0-9]{1,3}/192.168.16.21/g' "$hostsFile"  # Updates IP from .X to 21
    if [ $? -eq 0 ]; then
        echo "INFO: Hosts file updates successfully" | tee -a "$logFile"  
    else
        echo "ERROR: Hosts file update fails" | tee -a "$errorFile"  
    fi
}

apachePkg="apache2"
squidPkg="squid"

# CHECK IF PACKAGE INSTALLED
isInstalled() {                                   
    dpkg -s "$1" >/dev/null 2>&1        # Checks package status
}

# CHECK FOR OUTDATED PACKAGE
checkOutdated() {                                 
    pkg="$1"    # Sets package variable
    sudo apt update -y >/dev/null 2>&1  # Updates package cache
    installed=$(dpkg -s "$pkg" 2>/dev/null | awk -F': ' '/Version/ {print $2}') # Gets installed version
    latest=$(apt-cache policy "$pkg" | awk '/Candidate:/ {print $2}')  # Gets latest version
    [ -z "$installed" ] && return 0    # Skips if not installed
    [ "$installed" != "$latest" ] && echo "WARNING: $pkg is installed but not latest. Installed: $installed | Latest: $latest" | tee -a "$logFile"  # Prints warning
}

# INSTALL PACKAGES
installPackages() {                                
    for pkg in "$apachePkg" "$squidPkg"; do               # Loops packages
        if isInstalled "$pkg"; then                       # Checks installed
            echo "INFO: $pkg exists" | tee -a "$logFile"  # Logs existence
            checkOutdated "$pkg"                          # Checks outdated
        else
            echo "INSTALL: $pkg now" | tee -a "$logFile"             # Logs install
            sudo apt update -y >>"$logFile" 2>>"$errorFile"          # Updates apt
            sudo apt install -y "$pkg" >>"$logFile" 2>>"$errorFile"  # Installs package
        fi
    done
}

# START SERVICES
runServices() {                                   
    for svc in apache2 squid; do                 # Loops services
        echo "STARTING: $svc" | tee -a "$logFile"  # Logs start
        sudo systemctl enable "$svc" --now >>"$logFile" 2>>"$errorFile"  # Enables & starts
    done
}

# USER MANAGEMENT
userList=(dennis aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda)  # list of users
dennisPubKey="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"  #  dennis's key

createUser() {                                    
    u="$1"      # Sets username from argument
    if ! id "$u" &>/dev/null; then              # Checks user existence
        sudo useradd -m -s /bin/bash "$u"       # Creates user
        echo "INFO: User $u created" | tee -a "$logFile"  # Logs creation
    else
        echo "SKIP: User $u exists" | tee -a "$logFile"  # Logs skip
    fi
}

addSudoIfDennis() {                               
    u="$1"          # Sets username from argument
    if [ "$u" == "dennis" ] && ! groups "$u" | grep -qw sudo; then  # Checks 'dennis' not in superuser gorup
        sudo usermod -aG sudo "$u"    # Adds super user
        echo "INFO: $u added to sudo" | tee -a "$logFile"  # Logs add
    fi
}

setupSshKeys() {                                  
    u="$1"                                        # Sets username from argument
    sshDir="/home/$u/.ssh"                        # Sets ssh directory for that user
    sudo mkdir -p "$sshDir" && sudo chmod 700 "$sshDir" && sudo chown "$u:$u" "$sshDir"  # Create .ssh

    [ ! -f "$sshDir/id_rsa" ] && sudo -u "$u" ssh-keygen -t rsa -f "$sshDir/id_rsa" -N "" -q  # Creates RSA key
    [ ! -f "$sshDir/id_ed25519" ] && sudo -u "$u" ssh-keygen -t ed25519 -f "$sshDir/id_ed25519" -N "" -q  # Creates ED25519 key

    authKeys="$sshDir/authorized_keys"           # Sets authorized_keys path
    touch "$authKeys"                            # Creates file
    sudo chown "$u:$u" "$authKeys"               # Sets ownership
    sudo chmod 600 "$authKeys"                   # Sets permissions

    for key in "$sshDir/id_rsa.pub" "$sshDir/id_ed25519.pub"; do  # Loops keys
        pubKey=$(cat "$key")                     # Reads key
        if ! grep -Fxq "$pubKey" "$authKeys"; then  # Checks key
            echo "$pubKey" | sudo tee -a "$authKeys" >/dev/null  # Adds key
        fi
    done

    if [ "$u" == "dennis" ] && ! grep -Fxq "$dennisPubKey" "$authKeys"; then  # Adds extra key
        echo "$dennisPubKey" | sudo tee -a "$authKeys" >/dev/null
    fi

    echo "INFO: SSH keys ready for $u" | tee -a "$logFile"  # Logs completion
}

createAllUsers() {                              
    for u in "${userList[@]}"; do                 # Loops users
        createUser "$u"                           # Creates user
        addSudoIfDennis "$u"                      # Adds sudo if dennis
        setupSshKeys "$u"                         # Sets up SSH
    done
}

# MAIN EXECUTION
startLiveTimer
echo "INFO: SCRIPT STARTS" | tee -a "$logFile" 

editingHostsFile                                  # Edits hosts
netplanChange                                     # Changes netplan
installPackages                                   # Installs packages
runServices                                       # Starts services
createAllUsers                                    # Creates users

echo "---------------------------   DONE   ---------------------------------" >> $logFile
echo "---------------------------   DONE   ---------------------------------" >> $errorFile
stopLiveTimer
