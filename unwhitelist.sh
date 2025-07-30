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

# Attempt to delete IP from whitelist
$NFT delete element inet filter whitelist { $IP }
if [ $? -ne 0 ]; then
  echo "Failed to remove IP $IP from whitelist."
  exit 1
fi

# Save the ruleset for persistence
$NFT list ruleset > /etc/nftables.conf
echo "IP $IP removed from the blacklist"
exit 0
