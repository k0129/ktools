#!/bin/bash

confirm() {
  # $1 = prompt message
  while true; do
    read -r -p "$1 [y/N]: " response
    case "$response" in
      [yY][eE][sS]|[yY]) 
        return 0  # yes
        ;;
      [nN][oO]|[nN]|'') 
        return 1  # no or empty
        ;;
      *) 
        echo "Please answer yes or no."
        ;;
    esac
  done
}

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use: sudo $0)"
  exit 1
fi

read -p "Disabling and removing rules from any preconfigured firewall. Rules cannot be re-added. Press enter to confirm, CTRL+C to exit"

systemctl stop firewalld
systemctl disable firewalld
systemctl stop ufw
systemctl disable ufw
ufw reset
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -t raw -F
iptables -t raw -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
systemctl stop netfilter-persistent
systemctl disable netfilter-persistent

echo "\n\n"

read -p "Enter ports (comma separated, 0 = all ports, Enter = no ports): " ports_input

if [[ -z "$ports_input" ]]; then
  ports_block="{ }"
elif [[ "$ports_input" == "0" ]]; then
  ports_block="0-65535"
else
  ports_clean=$(echo "$ports_input" | tr -d ' ')
  ports_block="{ $ports_clean }"
fi

cat > firewall.example <<EOF
table inet filter {
    set whitelist {
        type ipv4_addr
        flags interval
    }

    set blacklist {
        type ipv4_addr
        flags interval
    }

    chain input {
        type filter hook input priority 0
        policy drop

        ip6 saddr ::/0 counter drop
        ip saddr @blacklist counter drop
        ct state invalid counter drop
        ip saddr @whitelist accept
        tcp flags == 0x0 counter drop                     # NULL scan
        tcp flags & (syn|fin|rst) == (syn|fin) counter drop  # SYN-FIN combination
        ip frag-off & 0x1fff != 0 counter drop
        ip protocol != { tcp, udp, icmp } counter drop
        ip protocol icmp icmp type echo-request limit rate 1/second accept
        tcp flags & (fin|psh|urg) == (fin|psh|urg) counter drop
        ct state established,related accept
        iif lo accept
        tcp dport $ports_block accept
    }


    chain output {
        type filter hook output priority 0
        policy accept

        ip daddr @blacklist reject
    }

    chain forward {
        type filter hook forward priority 0
        policy drop
    }
}
EOF

echo "Finished with allowed ports: $ports_block"
