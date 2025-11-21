#!/bin/bash
# Access Control - SSH, Sudo, PAM - Annexure B Section 6

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
echo "MODULE 6: ACCESS CONTROL (SSH, SUDO, PAM)" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

# 6.1 SSH Configuration
echo -e "\n[6.1] SSH Server Configuration..." | tee -a "$REPORT"

SSHD_CONFIG="/etc/ssh/sshd_config"

if [ -f "$SSHD_CONFIG" ]; then
    # Check permissions
    PERMS=$(stat -c "%a" "$SSHD_CONFIG")
    if [ "$PERMS" = "600" ]; then
        log_result "PASS" "  ✅ sshd_config permissions correct (600)"
    else
        log_result "FAIL" "  ❌ sshd_config permissions incorrect ($PERMS)"
        if [ "$MODE" = "fix" ]; then
            chmod 600 "$SSHD_CONFIG"
            chown root:root "$SSHD_CONFIG"
            log_result "INFO" "     🔧 Fixed: Set permissions to 600"
        fi
    fi
    
    # SSH hardening parameters
    SSH_PARAMS=(
        "PermitRootLogin:no:Root login disabled"
        "PermitEmptyPasswords:no:Empty passwords disabled"
        "PasswordAuthentication:no:Password auth disabled (use keys)"
        "PubkeyAuthentication:yes:Public key auth enabled"
        "IgnoreRhosts:yes:Rhosts ignored"
        "HostbasedAuthentication:no:Host-based auth disabled"
        "X11Forwarding:no:X11 forwarding disabled"
        "MaxAuthTries:3:Max auth tries set to 3"
        "MaxSessions:2:Max sessions limited"
        "ClientAliveInterval:300:Client alive interval set"
        "ClientAliveCountMax:0:Client alive count set"
        "LoginGraceTime:60:Login grace time limited"
        "LogLevel:INFO:Log level set to INFO"
        "UsePAM:yes:PAM enabled"
        "GSSAPIAuthentication:no:GSSAPI disabled"
    )
    
    for param_info in "${SSH_PARAMS[@]}"; do
        IFS=':' read -r key value desc <<< "$param_info"
        
        if grep -qE "^[[:space:]]*${key}[[:space:]]+${value}" "$SSHD_CONFIG"; then
            log_result "PASS" "  ✅ $desc ($key $value)"
        else
            log_result "FAIL" "  ❌ $desc not set correctly"
            if [ "$MODE" = "fix" ]; then
                # Remove existing lines and add new one
                sed -i "/^[[:space:]]*${key}/d" "$SSHD_CONFIG"
                echo "$key $value" >> "$SSHD_CONFIG"
                log_result "INFO" "     🔧 Fixed: Set $key $value"
            fi
        fi
    done
    
    # Ciphers
    if grep -qE "^Ciphers.*aes256-gcm|^Ciphers.*aes128-gcm|^Ciphers.*chacha20" "$SSHD_CONFIG"; then
        log_result "PASS" "  ✅ Strong ciphers configured"
    else
        log_result "WARN" "  ⚠️  Strong ciphers not explicitly set"
        if [ "$MODE" = "fix" ]; then
            sed -i "/^Ciphers/d" "$SSHD_CONFIG"
            echo "Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com" >> "$SSHD_CONFIG"
            log_result "INFO" "     🔧 Fixed: Set strong ciphers"
        fi
    fi
    
    # MACs
    if grep -qE "^MACs.*hmac-sha2-512|^MACs.*hmac-sha2-256" "$SSHD_CONFIG"; then
        log_result "PASS" "  ✅ Strong MACs configured"
    else
        log_result "WARN" "  ⚠️  Strong MACs not explicitly set"
        if [ "$MODE" = "fix" ]; then
            sed -i "/^MACs/d" "$SSHD_CONFIG"
            echo "MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256" >> "$SSHD_CONFIG"
            log_result "INFO" "     🔧 Fixed: Set strong MACs"
        fi
    fi
    
    if [ "$MODE" = "fix" ]; then
        systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null
    fi
fi

# 6.2 Sudo Configuration
echo -e "\n[6.2] Sudo Configuration..." | tee -a "$REPORT"

if command -v sudo &>/dev/null; then
    log_result "PASS" "  ✅ Sudo is installed"
    
    # Check sudo log
    if grep -qr "^Defaults.*logfile=" /etc/sudoers /etc/sudoers.d/ 2>/dev/null; then
        log_result "PASS" "  ✅ Sudo logging configured"
    else
        log_result "FAIL" "  ❌ Sudo logging not configured"
        if [ "$MODE" = "fix" ]; then
            echo "Defaults logfile=\"/var/log/sudo.log\"" > /etc/sudoers.d/logging
            chmod 440 /etc/sudoers.d/logging
            log_result "INFO" "     🔧 Fixed: Configured sudo logging"
        fi
    fi
    
    # Check use_pty
    if grep -qr "^Defaults.*use_pty" /etc/sudoers /etc/sudoers.d/ 2>/dev/null; then
        log_result "PASS" "  ✅ Sudo use_pty configured"
    else
        log_result "FAIL" "  ❌ Sudo use_pty not configured"
        if [ "$MODE" = "fix" ]; then
            echo "Defaults use_pty" > /etc/sudoers.d/use_pty
            chmod 440 /etc/sudoers.d/use_pty
            log_result "INFO" "     🔧 Fixed: Configured use_pty"
        fi
    fi
    
    # Check su restriction
    if grep -q "^auth.*required.*pam_wheel.so" /etc/pam.d/su 2>/dev/null; then
        log_result "PASS" "  ✅ su command restricted"
    else
        log_result "WARN" "  ⚠️  su command not restricted to wheel group"
        if [ "$MODE" = "fix" ]; then
            echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su
            log_result "INFO" "     🔧 Fixed: Restricted su to wheel group"
        fi
    fi
else
    log_result "FAIL" "  ❌ Sudo not installed"
    if [ "$MODE" = "fix" ]; then
        apt-get install -y sudo 2>/dev/null || yum install -y sudo 2>/dev/null
        log_result "INFO" "     🔧 Fixed: Installed sudo"
    fi
fi

# 6.3 PAM Configuration
echo -e "\n[6.3] PAM Configuration..." | tee -a "$REPORT"

# Check libpam-pwquality
if dpkg -l | grep -q libpam-pwquality 2>/dev/null || rpm -q libpwquality &>/dev/null; then
    log_result "PASS" "  ✅ libpam-pwquality installed"
else
    log_result "FAIL" "  ❌ libpam-pwquality not installed"
    if [ "$MODE" = "fix" ]; then
        apt-get install -y libpam-pwquality 2>/dev/null || yum install -y libpwquality 2>/dev/null
        log_result "INFO" "     🔧 Fixed: Installed libpam-pwquality"
    fi
fi

# Check password quality in pwquality.conf
PWQUALITY="/etc/security/pwquality.conf"
if [ -f "$PWQUALITY" ]; then
    # Minimum length
    if grep -qE "^minlen[[:space:]]*=[[:space:]]*[1][4-9]|^minlen[[:space:]]*=[[:space:]]*[2-9][0-9]" "$PWQUALITY"; then
        log_result "PASS" "  ✅ Minimum password length >= 14"
    else
        log_result "FAIL" "  ❌ Minimum password length not set"
        if [ "$MODE" = "fix" ]; then
            sed -i '/^minlen/d' "$PWQUALITY"
            echo "minlen = 14" >> "$PWQUALITY"
            log_result "INFO" "     🔧 Fixed: Set minlen=14"
        fi
    fi
    
    # Other quality checks
    PWQ_PARAMS=("dcredit=-1:digit required" "ucredit=-1:uppercase required" "lcredit=-1:lowercase required" "ocredit=-1:special char required")
    
    for param_info in "${PWQ_PARAMS[@]}"; do
        IFS=':' read -r param desc <<< "$param_info"
        key="${param%%=*}"
        if grep -qE "^${key}[[:space:]]*=" "$PWQUALITY"; then
            log_result "PASS" "  ✅ Password $desc"
        else
            log_result "WARN" "  ⚠️  Password $desc not set"
            if [ "$MODE" = "fix" ]; then
                echo "$param" >> "$PWQUALITY"
                log_result "INFO" "     🔧 Fixed: Set $param"
            fi
        fi
    done
fi

# Check faillock
if grep -qr "pam_faillock" /etc/pam.d/common-auth 2>/dev/null || \
   grep -qr "pam_faillock" /etc/pam.d/system-auth 2>/dev/null; then
    log_result "PASS" "  ✅ Account lockout (faillock) configured"
else
    log_result "WARN" "  ⚠️  Account lockout not configured"
    if [ "$MODE" = "fix" ]; then
        log_result "INFO" "     ⚠️  Manual configuration of pam_faillock required"
    fi
fi

# Summary
echo -e "\n================================================================" | tee -a "$REPORT"
echo "MODULE 6 SUMMARY: $PASSED passed, $FAILED failed/warnings" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

exit 0
