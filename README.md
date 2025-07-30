ktools is a suite of tools to manage ip blacklists and whitelists across computers and installs auditd

Components:
Mosquitto server: and MQTT broker that facilitates ip syncing
ipsyncd: daemon that handles updates
tools: adds commands: blacklist, unblacklist, whitelist, unwhitelist to /bin
                      usage: sudo blacklist <ip> [--noupdate]
