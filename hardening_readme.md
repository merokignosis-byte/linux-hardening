# Linux System Hardening Tool
## Annexure B Compliant Security Hardening Suite

### Overview
This comprehensive hardening toolkit implements all security controls specified in Annexure B from the National Technical Research Organisation. It provides automated scanning and remediation for 9 critical security domains.

---

## 📋 Features

✅ **9 Security Modules:**
1. **Filesystem Hardening** - Kernel modules, partition options
2. **Package Management** - Bootloader, ASLR, process hardening
3. **Services Configuration** - Disable unnecessary services, time sync
4. **Network Hardening** - Kernel parameters, firewall rules
5. **Host-Based Firewall** - UFW/iptables configuration
6. **Access Control** - SSH, Sudo, PAM hardening
7. **User Accounts** - Password policies, account security
8. **Logging & Auditing** - rsyslog, auditd, AIDE
9. **System Maintenance** - File permissions, integrity checks

✅ **Two Operating Modes:**
- **Scan Mode** - Audit-only, no changes made
- **Fix Mode** - Automatically remediate issues

✅ **Comprehensive Reporting** - Detailed TXT reports with pass/fail/warning status

---

## 🚀 Quick Start

### 1. Installation

```bash
# Download all files to a directory
mkdir linux-hardening && cd linux-hardening

# Save the Python controller as: hardening_controller.py
# Save bash scripts as: 1_filesystem.sh, 2_package_mgmt.sh, etc.

# Make all scripts executable
chmod +x hardening_controller.py
chmod +x *.sh

# Verify all 10 files are present
ls -l
# Should show:
# hardening_controller.py
# 1_filesystem.sh
# 2_package_mgmt.sh
# 3_services.sh
# 4_network.sh
# 5_firewall.sh
# 6_access_control.sh
# 7_user_accounts.sh
# 8_logging_auditing.sh
# 9_system_maintenance.sh
```

### 2. Run as Root

```bash
sudo python3 hardening_controller.py
```

---

## 📖 Usage Guide

### Main Menu Options

```
[1-9] - Run individual security module
[A]   - Run ALL modules (full system hardening)
[S]   - Scan Only mode (no fixes, report only)
[Q]   - Quit
```

### Example Workflows

#### **Full System Scan (No Changes)**
```bash
sudo python3 hardening_controller.py
# Select [S] for Scan Only
```

#### **Full System Hardening**
```bash
sudo python3 hardening_controller.py
# Select [A] and confirm with 'yes'
```

#### **Harden Specific Module**
```bash
sudo python3 hardening_controller.py
# Select module number (1-9)
# Choose: [1] Scan Only or [2] Scan & Fix
```

---

## 📊 Understanding Reports

Reports are saved as: `hardening_report_YYYYMMDD_HHMMSS.txt`

### Status Indicators

- ✅ **PASS** - Requirement met, properly configured
- ❌ **FAIL** - Security issue detected, needs fixing
- ⚠️ **WARN** - Potential issue or manual review needed
- 🔧 **Fixed** - Issue automatically remediated (fix mode only)
- ℹ️ **INFO** - Informational message

### Sample Report Section
```
[1.1] Disabling Unused Filesystem Kernel Modules...
  ✅ Module cramfs properly disabled
  ✅ Module freevxfs properly disabled
  ❌ Module usb-storage is loaded
     🔧 Fixed: Disabled usb-storage module
```

---

## 🔒 Security Modules Explained

### Module 1: Filesystem
- Disables unused filesystem kernel modules (cramfs, hfs, etc.)
- Configures mount options (nodev, nosuid, noexec)
- Hardens /tmp, /home, /var partitions

### Module 2: Package Management
- Secures bootloader configuration
- Enables ASLR and ptrace restrictions
- Configures warning banners
- Disables core dumps

### Module 3: Services
- Removes unnecessary server services
- Disables X Window System
- Configures time synchronization (NTP)
- Secures cron job permissions

### Module 4: Network
- Disables wireless and Bluetooth
- Blacklists risky network protocols (DCCP, RDS, SCTP)
- Hardens network kernel parameters
- Enables reverse path filtering, SYN cookies

### Module 5: Firewall
- Configures UFW with deny-by-default policy
- Sets up loopback rules
- Removes conflicting firewall tools

### Module 6: Access Control
- Hardens SSH (disables root login, enforces keys)
- Configures sudo logging and pty usage
- Implements PAM password quality requirements
- Sets account lockout policies

### Module 7: User Accounts
- Enforces password aging (90-day max)
- Requires strong password hashing (SHA512)
- Secures system accounts (nologin shell)
- Sets proper umask values
- Configures shell timeouts

### Module 8: Logging & Auditing
- Configures rsyslog and journald
- Installs and configures auditd
- Sets up comprehensive audit rules
- Implements AIDE file integrity checking
- Configures log rotation

### Module 9: System Maintenance
- Verifies critical file permissions (/etc/passwd, /etc/shadow)
- Identifies world-writable files
- Checks for unowned files
- Audits SUID/SGID binaries
- Validates password/group consistency
- Secures user home directories

---

## ⚠️ Important Warnings

### Before Running in Fix Mode:

1. **Backup Your System** - Always create a snapshot/backup
2. **Test Environment First** - Run on non-production systems initially
3. **Review Reports** - Check scan-only results before applying fixes
4. **SSH Access** - Module 6 changes SSH config; ensure you have console access
5. **Network Services** - Module 3 may disable services you need
6. **Firewall Rules** - Module 5 applies restrictive firewall policies

### Manual Actions Required

Some settings require manual intervention:

- **Bootloader Password** - Set with `grub-mkpasswd-pbkdf2`
- **AIDE Initialization** - Run `aideinit` after installation
- **SSH Key Setup** - Configure before disabling password auth
- **Firewall Rules** - Add rules for specific services you need

---

## 🛠️ Troubleshooting

### Script Won't Run
```bash
# Check Python version (3.6+ required)
python3 --version

# Verify root access
sudo whoami  # Should output "root"

# Check file permissions
ls -l *.sh  # Should show -rwxr-xr-x
```

### SSH Lockout Prevention
Before Module 6 in fix mode:
```bash
# Ensure you have SSH keys configured
ssh-copy-id user@your-server

# Test key-based login
ssh -i ~/.ssh/id_rsa user@your-server

# Keep an active SSH session open during hardening
```

### Service Issues
If critical services stop:
```bash
# Check service status
systemctl status servicename

# View recent logs
journalctl -xe

# Revert specific changes
systemctl enable servicename
systemctl start servicename
```

### Firewall Lockout
```bash
# If UFW blocks you, disable temporarily
sudo ufw disable

# Add your IP before enabling
sudo ufw allow from YOUR_IP

# Re-enable
sudo ufw enable
```

---

## 📝 Best Practices

1. **Incremental Hardening** - Run modules one at a time
2. **Document Changes** - Keep reports for audit trail
3. **Regular Scans** - Schedule monthly compliance checks
4. **Update Regularly** - Keep scripts updated with new threats
5. **Customize Rules** - Adapt to your environment's needs

---

## 🔄 Automation

### Scheduled Compliance Scans
```bash
# Add to crontab for monthly scans
sudo crontab -e

# Add this line (runs 1st of every month at 2 AM)
0 2 1 * * cd /path/to/hardening && python3 hardening_controller.py << EOF
S
EOF
```

---

## 📞 Support

For issues or enhancements:
- Review Annexure B documentation
- Check system logs: `journalctl -xe`
- Examine report files for detailed findings

---

## 📄 License & Credits

**Organization:** National Technical Research Organisation  
**Category:** Software - Cyber Security  
**Compliance Standard:** Annexure B Security Requirements

---

## ✅ Pre-Deployment Checklist

- [ ] Backed up system/VM snapshot
- [ ] Tested on non-production system
- [ ] Reviewed scan-only results
- [ ] Configured SSH keys (if hardening SSH)
- [ ] Documented required services
- [ ] Have console/physical access
- [ ] Reviewed network connectivity requirements
- [ ] Notified team of maintenance window

---

**Remember:** Security hardening is a balance between protection and usability. Always understand the impact of changes before applying them to production systems!
