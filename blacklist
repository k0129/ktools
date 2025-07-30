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

# Check if IP is in whitelist
if $NFT list set inet filter whitelist | grep -q "$IP"; then
  echo "IP $IP is in the whitelist — not adding to blacklist."
  exit 1
fi

# Check if IP is already in blacklist
if $NFT list set inet filter blacklist | grep -q "$IP"; then
  echo "IP $IP is already in the blacklist."
  exit 0
fi

# Add IP to blacklist set
$NFT add element inet filter blacklist { $IP }
if [ $? -ne 0 ]; then
  echo "Failed to add IP $IP to blacklist."
  exit 1
fi

# Save ruleset to file
$NFT list ruleset > /etc/nftables.conf

echo "IP $IP added to the blacklist"
exit 0
