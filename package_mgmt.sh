#!/bin/bash
# Package Management & Boot Security - Annexure B Section 2

MODE=${1:-scan}
REPORT=${2:-hardening_report.txt}
FAILED=0
PASSED=0

log_result() {
    local status=$1
    local message=$2
    echo "$message" | tee -a "$REPORT"
    if [ "$status" = "PASS" ]; then ((PASSED++)); else ((FAILED++)); fi
}

echo "================================================================" | tee -a "$REPORT"
echo "MODULE 2: PACKAGE MANAGEMENT & BOOT SECURITY" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

# 2.1 Configure Bootloader
echo -e "\n[2.1] Bootloader Security..." | tee -a "$REPORT"

# Check GRUB password
if [ -f /boot/grub/grub.cfg ]; then
    if grep -q "^set superusers" /boot/grub/grub.cfg; then
        log_result "PASS" "  ✅ Bootloader password is set"
    else
        log_result "FAIL" "  ❌ Bootloader password not set"
        if [ "$MODE" = "fix" ]; then
            log_result "INFO" "     ⚠️  Manual action required: Set bootloader password with grub-mkpasswd-pbkdf2"
        fi
    fi
    
    # Check grub.cfg permissions
    PERMS=$(stat -c "%a" /boot/grub/grub.cfg)
    if [ "$PERMS" = "400" ] || [ "$PERMS" = "600" ]; then
        log_result "PASS" "  ✅ Bootloader config permissions correct ($PERMS)"
    else
        log_result "FAIL" "  ❌ Bootloader config permissions incorrect ($PERMS)"
        if [ "$MODE" = "fix" ]; then
            chmod 600 /boot/grub/grub.cfg
            chown root:root /boot/grub/grub.cfg
            log_result "INFO" "     🔧 Fixed: Set permissions to 600"
        fi
    fi
fi

# 2.2 Additional Process Hardening
echo -e "\n[2.2] Process Hardening..." | tee -a "$REPORT"

# ASLR (Address Space Layout Randomization)
ASLR=$(sysctl -n kernel.randomize_va_space 2>/dev/null)
if [ "$ASLR" = "2" ]; then
    log_result "PASS" "  ✅ ASLR is enabled (value: 2)"
else
    log_result "FAIL" "  ❌ ASLR not properly configured (value: $ASLR)"
    if [ "$MODE" = "fix" ]; then
        echo "kernel.randomize_va_space = 2" > /etc/sysctl.d/90-aslr.conf
        sysctl -w kernel.randomize_va_space=2
        log_result "INFO" "     🔧 Fixed: Enabled ASLR"
    fi
fi

# Ptrace scope
PTRACE=$(sysctl -n kernel.yama.ptrace_scope 2>/dev/null)
if [ "$PTRACE" = "1" ] || [ "$PTRACE" = "2" ]; then
    log_result "PASS" "  ✅ Ptrace scope is restricted (value: $PTRACE)"
else
    log_result "FAIL" "  ❌ Ptrace scope not restricted (value: $PTRACE)"
    if [ "$MODE" = "fix" ]; then
        echo "kernel.yama.ptrace_scope = 1" > /etc/sysctl.d/90-ptrace.conf
        sysctl -w kernel.yama.ptrace_scope=1 2>/dev/null
        log_result "INFO" "     🔧 Fixed: Restricted ptrace scope"
    fi
fi

# Core dumps
if grep -q "hard core 0" /etc/security/limits.conf; then
    log_result "PASS" "  ✅ Core dumps are restricted"
else
    log_result "FAIL" "  ❌ Core dumps not restricted"
    if [ "$MODE" = "fix" ]; then
        echo "* hard core 0" >> /etc/security/limits.conf
        echo "fs.suid_dumpable = 0" > /etc/sysctl.d/90-coredump.conf
        sysctl -w fs.suid_dumpable=0
        log_result "INFO" "     🔧 Fixed: Disabled core dumps"
    fi
fi

# Prelink check
if command -v prelink &>/dev/null; then
    log_result "FAIL" "  ❌ Prelink is installed"
    if [ "$MODE" = "fix" ]; then
        apt-get remove -y prelink 2>/dev/null || yum remove -y prelink 2>/dev/null
        log_result "INFO" "     🔧 Fixed: Removed prelink"
    fi
else
    log_result "PASS" "  ✅ Prelink is not installed"
fi

# 2.3 Warning Banners
echo -e "\n[2.3] Configuring Warning Banners..." | tee -a "$REPORT"

BANNER_TEXT="Authorized access only. All activity may be monitored and reported."

for file in /etc/issue /etc/issue.net /etc/motd; do
    if [ -f "$file" ]; then
        PERMS=$(stat -c "%a" "$file")
        if [ "$PERMS" = "644" ]; then
            log_result "PASS" "  ✅ $file permissions correct"
        else
            log_result "FAIL" "  ❌ $file permissions incorrect ($PERMS)"
            if [ "$MODE" = "fix" ]; then
                chmod 644 "$file"
                chown root:root "$file"
                log_result "INFO" "     🔧 Fixed: Set $file permissions to 644"
            fi
        fi
        
        if [ ! -s "$file" ] && [ "$MODE" = "fix" ]; then
            echo "$BANNER_TEXT" > "$file"
            log_result "INFO" "     🔧 Fixed: Added warning banner to $file"
        fi
    fi
done

# Summary
echo -e "\n================================================================" | tee -a "$REPORT"
echo "MODULE 2 SUMMARY: $PASSED passed, $FAILED failed/warnings" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

exit 0
