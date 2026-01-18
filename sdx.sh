#!/bin/bash

# Exit on error
set -e

# Function to print verbose messages
verbose() {
  echo -e "\033[1;32m[INFO]\033[0m $1"
}

# Function to print error messages
error_message() {
  echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# Pre-setup: Set timezone and NTP
verbose "Setting up timezone and NTP."
timedatectl set-timezone Europe/Vienna
verbose "Timezone set to Europe/Vienna."
timedatectl set-ntp true
verbose "NTP enabled."

# Function to execute a command and check for success
execute_command() {
    local cmd="$1"
    verbose "Executing: $cmd"
    eval "$cmd"
    local status=$?
    if [ $status -ne 0 ]; then
        error_message "Command failed -> $cmd"
        exit 1
    fi
}

# Function to validate drive names and normalize sdX names
normalize_drive() {
    local device="$1"
    if [[ "$device" =~ ^/dev/sd[a-z]+$ ]]; then
        echo "$device"
    else
        error_message "Unsupported device format: $device. Only /dev/sdX is allowed."
        exit 1
    fi
}

validate_drive() {
    local device="$1"
    if [[ ! -e "$device" ]]; then
        error_message "Invalid device: $device does not exist."
        exit 1
    fi
}

# Function to list and select drives for secure erase
select_drives() {
    verbose "Listing available /dev/sdX disk devices..."
    lsblk -d -o NAME,SIZE,MODEL,TYPE
    verbose "Note: Only whole-disk devices like /dev/sdX are supported. Do NOT use partition devices like /dev/sdX1."

    local example_device=$(lsblk -d -n -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}' | grep -E '^/dev/sd[a-z]+$' | head -n1)

    read -p "Enter the target drive(s) (space-separated, e.g., $example_device): " -a selected_drives
}

# Secure erase for ATA/SATA drives (sdX) via hdparm
secure_erase() {
    local device=$(normalize_drive "$1")
    local security_password="PasSWorD"

    execute_command "hdparm --user-master u --security-set-pass $security_password $device"
    execute_command "hdparm --user-master u --security-erase-enhanced $security_password $device"
}

# Get user selection
select_drives

# Wipe existing filesystem/RAID signatures on selected drives
for drive in "${selected_drives[@]}"; do
    drive=$(normalize_drive "$drive")
    validate_drive "$drive"
    execute_command "wipefs --all $drive"
done

# Loop through selected drives and perform secure erase
for drive in "${selected_drives[@]}"; do
    drive=$(normalize_drive "$drive")
    validate_drive "$drive"
    secure_erase "$drive"
done

verbose "Secure erase completed successfully."
