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

# Attempt to delete IP from blacklist
$NFT delete element inet filter blacklist { $IP }
if [ $? -ne 0 ]; then
  echo "Failed to remove IP $IP from blacklist."
  exit 1
fi

# Save updated ruleset
$NFT list ruleset > /etc/nftables.conf
echo "IP $IP removed from the blacklist"
exit 0
