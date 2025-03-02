#!/bin/bash

# ==============================================
# Script: remove_cpanel_nginx.sh
# Purpose: Safely remove cPanel, WHM, Engintron, Apache, and install Nginx
# Adds logging, error handling, and OS detection
# ==============================================

LOG_FILE="/var/log/remove_cpanel.log"

# Logging function
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') | $1" | tee -a "$LOG_FILE"
}

# Detect OS
OS=""
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
else
    log "Unable to detect OS. Exiting..."
    exit 1
fi

log "Starting cPanel & Apache removal script on $OS"

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to remove a directory safely
remove_dir() {
    if [[ -d "$1" ]]; then
        log "Removing directory: $1"
        rm -rf "$1"
    else
        log "Directory not found, skipping: $1"
    fi
}

# Stop and remove cPanel/WHM if installed
if command_exists /usr/local/cpanel/bin/cpanel; then
    log "Stopping cPanel services..."
    for service in $(/usr/local/cpanel/bin/cpanel restart 2>/dev/null); do 
        systemctl stop $service 2>/dev/null
        systemctl disable $service 2>/dev/null
    done
    log "cPanel services stopped."

    log "Removing cPanel files..."
    remove_dir /usr/local/cpanel
    remove_dir /var/cpanel
    remove_dir /usr/local/apache
    remove_dir /usr/local/lib/php
    remove_dir /usr/local/lib/cpanel
    remove_dir /usr/local/bin/cpanel
    remove_dir /usr/local/cpanel-whm

    log "cPanel files removed."
else
    log "cPanel not found, skipping removal."
fi

# Remove Engintron (Nginx for cPanel) if present
if [[ -d "/usr/local/src/engintron" ]]; then
    log "Removing Engintron..."
    remove_dir /etc/nginx/
    remove_dir /usr/local/src/engintron
    log "Engintron removed."
else
    log "Engintron not found, skipping."
fi

# Stop Apache if running
if systemctl list-units --type=service | grep -q "httpd\|apache2"; then
    log "Stopping Apache..."
    systemctl stop httpd 2>/dev/null
    systemctl stop apache2 2>/dev/null
    systemctl disable httpd 2>/dev/null
    systemctl disable apache2 2>/dev/null
    log "Apache stopped."
else
    log "Apache is not running, skipping stop."
fi

# Remove Apache if installed
if command_exists yum; then
    log "Removing Apache (YUM)..."
    yum remove -y httpd 2>/dev/null
elif command_exists apt; then
    log "Removing Apache (APT)..."
    apt remove -y apache2 2>/dev/null
else
    log "Could not determine package manager, skipping Apache removal."
fi

log "Apache removed."

# Install Fresh Nginx
if command_exists yum; then
    log "Installing Nginx (YUM)..."
    yum install -y nginx 2>/dev/null
elif command_exists apt; then
    log "Installing Nginx (APT)..."
    apt install -y nginx 2>/dev/null
fi

if systemctl start nginx; then
    systemctl enable nginx
    log "Nginx installed and started."
else
    log "Failed to start Nginx."
fi

# Remove cPanel Redirects
log "Removing cPanel redirects..."
remove_dir /var/www/html/cgi-sys/
remove_dir /usr/local/apache/htdocs/cgi-sys/

# Clean Firewall Rules (if applicable)
if command_exists firewall-cmd; then
    log "Cleaning Firewall Rules..."
    firewall-cmd --remove-service=cPanel --permanent 2>/dev/null
    firewall-cmd --remove-service=whm --permanent 2>/dev/null
    firewall-cmd --reload 2>/dev/null
    log "Firewall cleaned."
fi

# Remove old iptables rules
if command_exists iptables; then
    log "Cleaning iptables rules..."
    iptables -D INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport 2082 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport 2083 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport 2086 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport 2087 -j ACCEPT 2>/dev/null
    service iptables save 2>/dev/null
    log "iptables rules cleaned."
fi

# Restart the Server
log "Rebooting Server in 10 seconds..."
sleep 10
reboot
