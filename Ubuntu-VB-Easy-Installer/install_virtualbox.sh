#!/bin/bash
#
# This script automates the installation of VirtualBox for Debian-based systems.
#
# Shane Sexton
# 10 10 2019
#


# Variables
LOG_FILE="install.log"
KEY_NAME="oracle_vbox_2016.asc"
VBOX_VERSION="virtualbox-5.1"

# Check if root
check_root () {
  echo "Checking permissions..."

  if [ "$(whoami)" = "root" ]; then
    echo "Running with sufficient permissions."
  elif [ "$(whoami)" != "root" ]; then
    echo "Please run this script with sudo."
    exit 1
  fi
}


# Run updates
update_packages () {
  echo "Updating packages..."

  apt-get update -y >> $LOG_FILE
  apt-get upgrade -y > /dev/null 2>> $LOG_FILE 
}

# Determine version and create DEB entry
determine_version () {
  echo "Determining release version..." | tee -a $LOG_FILE
  
  # Check either os-release or lsb-release for version information  
  if [ -f /etc/os-release ]; then
    echo "Found /etc/os-release..." | tee -a $LOG_FILE
    . /etc/os-release
    VERSION=$VERSION_CODENAME
  elif [ -f /etc/lsb-release]; then
    echo "Found /etc/lsb-release..." | tee -a $LOG_FILE
    . /etc/lsb-release
    VERSION=$DISTRIB_CODENAME
  fi
  # Create a deb entry using the gather version information
  DEB_ENTRY="deb https://download.virtualbox.org/virtualbox/debian $VERSION contrib"
}

# Install VirtualBox
install_virtualbox () {
  echo "Checking for /etc/apt/sources.list..." | tee -a $LOG_FILE
  
  # Check whether there is a sources.list, or create a new virtualbox.list
  if [ -f /etc/apt/sources.list ]; then
    echo "Found /etc/apt/sources.list" | tee -a $LOG_FILE
    echo $DEB_ENTRY >> /etc/apt/sources.list
  else
    echo "Creating new entry in /etc/apt/sources.list.d/$KEY_NAME" | tee -a $LOG_FILE
    echo $DEB_ENTRY >> /etc/apt/sources.list.d/virtualbox.list
  fi
  
  echo "Checking whether wget is installed..." | tee -a $LOG_FILE
  
  # Check whether wget is intalled, and install if it isn't there
  if ! type wget &> /dev/null; then
    echo "Can't find wget. Installing..." | tee -a $LOG_FILE
    apt-get install -y wget  >> $LOG_FILE
  elif type wget &> /dev/null; then
    echo "Found wget. Yay!" | tee -a $LOG_FILE
  fi

  echo "Downloading key..." | tee -a $LOG_FILE

  # Wget the Oracle VirtualBox key
  wget -q https://www.virtualbox.org/download/$KEY_NAME >> $LOG_FILE

  # Make sure the key is successfully acquired
  if [ -f $KEY_NAME ]; then
    echo "Key acquired. Adding key." | tee -a $LOG_FILE
    apt-key add $KEY_NAME
  elif [ ! -f $KEY_NAME ]; then
    echo "Failed to get key..." | tee -a $LOG_FILE
    exit 1
  fi
  
  echo "Updating repos and packages..." | tee -a $LOG_FILE
  
  # Update packages
  update_packages
  
  echo "Installing $VBOX_VERSION" | tee -a $LOG_FILE
  
  # Install VirtualBox
  apt-get install -y $VBOX_VERSION >> $LOG_FILE
}

# Run functons
check_root
determine_version
install_virtualbox


