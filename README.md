# ktools

**ktools** is a suite of tools to simplify managing ip sets.

---

## Main Component
- **tools**  
  A set of command-line utilities:
  - `blacklist`
  - `unblacklist`
  - `whitelist`
  - `unwhitelist`

---

## Usage

```bash
sudo blacklist <ip>
```

---

## Installation

1. Download the repository.
2. Make tools executable (`chmod +x`)
3. Run!

> **Note:** If you're downloading via `curl`, be sure to use the `-L` flag to follow redirects.

---

## Additional tools
Additional scripts are packaged in addtl 
- `auditd-install.sh` installs auditd and configures some default rules
- `firewall-example.sh` creates an example firewall config with lots of rules.
