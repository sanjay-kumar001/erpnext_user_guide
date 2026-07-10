#!/usr/bin/env bash

###############################################################################
# Disable Unnecessary Services
#
# Target:
#   Ubuntu 24.04
#   DigitalOcean Droplet
#   ERPNext Production
#
# Author : Sanjay Kumar
###############################################################################

set -euo pipefail

echo "==============================================="
echo " Disable Unnecessary Ubuntu Services"
echo "==============================================="
echo

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root or using sudo."
    exit 1
fi

disable_service() {

    SERVICE="$1"

    if systemctl list-unit-files | grep -q "^${SERVICE}"; then

        echo "Disabling ${SERVICE}..."

        systemctl stop "${SERVICE}" 2>/dev/null || true
        systemctl disable "${SERVICE}" 2>/dev/null || true

    else

        echo "Skipping ${SERVICE} (not installed)"

    fi
}

mask_service() {

    SERVICE="$1"

    if systemctl list-unit-files | grep -q "^${SERVICE}"; then

        echo "Masking ${SERVICE}..."

        systemctl stop "${SERVICE}" 2>/dev/null || true
        systemctl disable "${SERVICE}" 2>/dev/null || true
        systemctl mask "${SERVICE}" 2>/dev/null || true

    else

        echo "Skipping ${SERVICE} (not installed)"

    fi
}

###############################################################################
# Crash Reporting
###############################################################################

disable_service apport.service
disable_service apport-autoreport.path
disable_service apport-forward.socket

###############################################################################
# Ubuntu News
###############################################################################

disable_service motd-news.timer

###############################################################################
# Update Notifier
###############################################################################

disable_service update-notifier-download.timer
disable_service update-notifier-motd.timer

###############################################################################
# Firmware Updates
###############################################################################

disable_service fwupd-refresh.timer

###############################################################################
# Modem Manager
###############################################################################

disable_service ModemManager.service

###############################################################################
# VMware Tools
###############################################################################

disable_service open-vm-tools.service
disable_service vgauth.service

###############################################################################
# Multipath Storage
###############################################################################

mask_service multipathd.service
disable_service multipathd.socket

###############################################################################
# iSCSI
###############################################################################

disable_service open-iscsi.service
disable_service iscsid.socket

###############################################################################
# Canonical Pollinate
###############################################################################

disable_service pollinate.service

###############################################################################
# Summary
###############################################################################

echo
echo "==============================================="
echo "Completed."
echo "==============================================="
echo
echo "Reboot recommended."
echo