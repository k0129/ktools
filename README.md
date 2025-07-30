# ktools

**ktools** is a suite of tools designed to manage IP blacklists and whitelists across multiple computers. It also installs `auditd` for system auditing.

---

## Components

- **Mosquitto server**  
  An MQTT broker that facilitates IP synchronization between systems.

- **ipsetsyncd**  
  A daemon that handles IP updates automatically.

- **tools**  
  A set of command-line utilities added to `/bin`:
  - `blacklist`
  - `unblacklist`
  - `whitelist`
  - `unwhitelist`

---

## Usage

```bash
sudo blacklist <ip> [--noupdate]
```

Use the optional `--noupdate` flag to prevent immediate synchronization.

---

## Installation

1. Download the repository.
2. Make the installer executable:

   ```bash
   sudo chmod +x install.sh
   ```

3. Run the installer:

   ```bash
   sudo ./install.sh
   ```

> **Note:** If you're downloading via `curl`, be sure to use the `-L` flag to follow redirects.
