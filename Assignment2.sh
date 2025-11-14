#!/bin/bash


errorFile="scriptErrorFile"
logFile="scriptLogFile"

[ -f "$errorFile" ]  || touch "$errorFile"
[ -f "$logFile" ]  || touch "$logFile"


# TRY AND ERROR BLOCK FOR MKDIR NETPLAN DIR
if [ ! -d /etc/netplan ]
then
    sudo mkdir -p /etc/netplan 2>/dev/null
    if [ $? -eq 0 ]
	then
        echo "NETPLAN DIR. CREATED"
    fi
fi


netplanFiles="$(ls /etc/netplan/)"
newNetplanFile="/etc/netplan/$(date +%Y-%m-%d)-netplan.yaml"


newNetplan(){
	echo "NO NETPLAN FILE FOUND"
	echo "CREATING AND CONFIGURING NEW FILE"
	touch "$newNetplanFile"
cat << EOF > $newNetplanFile
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
EOF
	echo "CONFIGURING NEW FILE SUCCESS"
	sleep 1

	echo "APPLYING NEW CONFIGS TO THE SYSTEM"
	sudo netplan apply >>"$logFile" 2>>"$errorFile"
	return $?
}

netplanApply(){
	echo "NETPLAN APPLY STARTING"
	if sudo netplan apply >>"$logFile" 2>>"$errorFile"
	then
    	echo "CHANGED TO --> $(ip -o -4 addr show | awk '/192.168.16.21/ {print $2, $4}')" | tee -a "$logFile"
		echo "NETPLAN APPLY SUCCESS"
	else
    	echo "UNABLE TO APPLY NETPLAN CHANGES" | tee -a "$errorFile" >&2
	fi
}

netplanChange() {
	echo "NETPLAN EDITING STARTED"
	if [ -z "$netplanFiles" ]
	then
    	echo "NO NETPLAN FILES FOUND, CREATING NEW FILES"
		newNetplan
		return 0
	else
		echo "GOING FURTHER WITH NETPLAN FILES: $netplanFiles"
		netplanFiles=(/etc/netplan/*.yaml)
		fileCount=${#netplanFiles[@]}
	fi
       
    if [ $fileCount -eq 1 ]
	then
        newHost=21

        # Update Address
        for file in "${netplanFiles[@]}"; do
            sed -i -E "s#(192\.168\.16\.)[0-9]{1,3}(/24)#\1${newHost}\2#g" "$file"
        done
		echo "NETPLAN EDITING COMPLETED"
        netplanApply

        # Rename the file
        currentFile="${netplanFiles[0]}"
        if [ "$currentFile" = "$newNetplanFile" ]
		then
            echo "SKIPPING RENAME PROCESS" | tee -a "$logFile"
			return 0
        else
            mv "$currentFile" "$newNetplanFile"
            echo "RENAMED NETPLAN FILE TO $newNetplanFile" | tee -a "$logFile"
			return 0
        fi

    elif [ $fileCount -gt 1 ]
	then
        for file in "${netplanFiles[@]}"; do
            mv "$file" "${file}.bak"
            echo "Backed up $file -> ${file}.bak" | tee -a "$logFile"
        done
        newNetplan
        netplanApply
		return 0
    fi
}

echo "LET THE SCRIPT END. DO NOT TRY TO IT FORCEFULLY"
echo ""

edtingHostsFile(){
hostsFile="/etc/hosts"

# Check if /etc/hosts exists
if [ ! -f "$hostsFile" ]
then
    sudo touch "$hostsFile" 2>/dev/null
sudo bash -c << EOF > $hostsFile
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters


192.168.16.21 server2
172.16.1.242 server2-mgmt
192.168.16.21 openwrt
172.16.1.2 openwrt-mgmt
EOF
    if [ $? -eq 0 ]
	then
        echo "$hostsFile CREATED AND ADDED DEFAULTS"
        sudo chmod 644 "$hostsFile"
    fi
fi

	echo "EDITING /etc/hosts FILE"

	#  /etc/hosts file changes
	sudo sed -i -E 's/192\.168\.16\.[0-9]{1,3}/192.168.16.21/g' /etc/hosts
	if [ $? -eq 0 ]

	then
		echo "EDITING /etc/hosts FILE SUCCESS" | tee -a "$logFile"
		return 0
	else
		echo "EDITING /etc/hosts FILE FAILED" | tee -a "$errorFile" >&2
		return 2
	fi
}


edtingHostsFile
netplanChange

:'
MORE TO COME

	TASKS LEFT TO ADD
		ADD SOFTWARES AND MAKE THEM RUN
			- APACHE2
			- SQUID

		ADD MANY USERS [MANY MANY...]
		ADD ONE SUPER USER [DENNIS]
'

# THANKSYOU FOR SCRATCHING YOUR HEAD WHILE CHECKING OUT MY SCRIPT.
