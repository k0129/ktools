#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use: sudo $0 <IP>)"
  exit 1
fi

# Ensure an IP argument is provided
if [ -z "$1" ]; then
  echo "Usage: sudo $0 <IP>"
  exit 1
fi

IP="$1"
NFT="nft -nn"

# Check if IP is in blacklist
if $NFT list set inet filter blacklist | grep -q "$IP"; then
  echo "IP $IP is in the blacklist — not adding to whitelist."
  exit 1
fi

# Check if IP is already in whitelist
if $NFT list set inet filter whitelist | grep -q "$IP"; then
  echo "IP $IP is already in the whitelist."
  exit 0
fi

# Add IP to whitelist set
$NFT add element inet filter whitelist { $IP }
if [ $? -ne 0 ]; then
  echo "Failed to add IP $IP to whitelist."
  exit 1
fi

# Save the ruleset for persistence
$NFT list ruleset > /etc/nftables.conf

echo "IP $IP added to the whitelist"
exit 0
