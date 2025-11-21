#!/bin/bash
# Logging & Auditing - Annexure B Section 8

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
echo "MODULE 8: LOGGING & AUDITING" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

# 8.1 System Logging - journald
echo -e "\n[8.1] Systemd-journald Configuration..." | tee -a "$REPORT"

if systemctl is-active systemd-journald &>/dev/null; then
    log_result "PASS" "  ✅ systemd-journald is active"
    
    # Check journald configuration
    if [ -f /etc/systemd/journald.conf ]; then
        if grep -qE "^Storage=persistent" /etc/systemd/journald.conf; then
            log_result "PASS" "  ✅ Journal storage set to persistent"
        else
            log_result "WARN" "  ⚠️  Journal storage not persistent"
            if [ "$MODE" = "fix" ]; then
                sed -i 's/^#Storage=.*/Storage=persistent/' /etc/systemd/journald.conf
                echo "Storage=persistent" >> /etc/systemd/journald.conf
                systemctl restart systemd-journald
                log_result "INFO" "     🔧 Fixed: Set journal storage to persistent"
            fi
        fi
    fi
else
    log_result "FAIL" "  ❌ systemd-journald not active"
fi

# 8.2 rsyslog Configuration
echo -e "\n[8.2] Rsyslog Configuration..." | tee -a "$REPORT"

if systemctl is-active rsyslog &>/dev/null; then
    log_result "PASS" "  ✅ rsyslog is active"
    
    # Check rsyslog configuration
    if [ -f /etc/rsyslog.conf ]; then
        # Check file creation mode
        if grep -qE '^\$FileCreateMode 0[64]40' /etc/rsyslog.conf /etc/rsyslog.d/*.conf 2>/dev/null; then
            log_result "PASS" "  ✅ rsyslog file creation mode configured"
        else
            log_result "WARN" "  ⚠️  rsyslog file creation mode not configured"
            if [ "$MODE" = "fix" ]; then
                echo '$FileCreateMode 0640' >> /etc/rsyslog.d/file-perms.conf
                systemctl restart rsyslog
                log_result "INFO" "     🔧 Fixed: Set file creation mode"
            fi
        fi
        
        # Check if logging rules exist
        if grep -qE "^\*\.\*|^auth,authpriv\.\*|^kern\.\*" /etc/rsyslog.conf /etc/rsyslog.d/*.conf 2>/dev/null; then
            log_result "PASS" "  ✅ rsyslog logging rules configured"
        else
            log_result "WARN" "  ⚠️  rsyslog logging rules may be incomplete"
        fi
    fi
elif systemctl is-enabled rsyslog &>/dev/null; then
    log_result "FAIL" "  ❌ rsyslog installed but not active"
    if [ "$MODE" = "fix" ]; then
        systemctl start rsyslog
        systemctl enable rsyslog
        log_result "INFO" "     🔧 Fixed: Started rsyslog"
    fi
else
    log_result "WARN" "  ⚠️  rsyslog not installed"
    if [ "$MODE" = "fix" ]; then
        apt-get install -y rsyslog 2>/dev/null || yum install -y rsyslog 2>/dev/null
        systemctl enable rsyslog
        systemctl start rsyslog
        log_result "INFO" "     🔧 Fixed: Installed and started rsyslog"
    fi
fi

# 8.3 Log File Permissions
echo -e "\n[8.3] Log File Permissions..." | tee -a "$REPORT"

LOG_DIRS=("/var/log")
PERM_ISSUES=0

for logdir in "${LOG_DIRS[@]}"; do
    if [ -d "$logdir" ]; then
        while IFS= read -r -d '' logfile; do
            PERMS=$(stat -c "%a" "$logfile")
            if [ "$PERMS" -gt 640 ] 2>/dev/null; then
                ((PERM_ISSUES++))
                if [ "$MODE" = "fix" ]; then
                    chmod 640 "$logfile"
                fi
            fi
        done < <(find "$logdir" -type f -name "*.log" -print0 2>/dev/null | head -20)
    fi
done

if [ "$PERM_ISSUES" -eq 0 ]; then
    log_result "PASS" "  ✅ Log file permissions properly configured"
else
    log_result "WARN" "  ⚠️  $PERM_ISSUES log files with excessive permissions"
    if [ "$MODE" = "fix" ]; then
        log_result "INFO" "     🔧 Fixed: Corrected log file permissions"
    fi
fi

# 8.4 Auditd Configuration
echo -e "\n[8.4] Auditd System..." | tee -a "$REPORT"

if command -v auditd &>/dev/null || command -v auditctl &>/dev/null; then
    log_result "PASS" "  ✅ Auditd packages installed"
    
    # Check if auditd is active
    if systemctl is-active auditd &>/dev/null; then
        log_result "PASS" "  ✅ Auditd service is active"
    else
        log_result "FAIL" "  ❌ Auditd not active"
        if [ "$MODE" = "fix" ]; then
            systemctl enable auditd
            systemctl start auditd
            log_result "INFO" "     🔧 Fixed: Started auditd"
        fi
    fi
    
    # Check audit rules
    if [ -f /etc/audit/rules.d/audit.rules ] || [ -f /etc/audit/audit.rules ]; then
        RULE_COUNT=$(auditctl -l 2>/dev/null | grep -c "^-")
        if [ "$RULE_COUNT" -gt 10 ]; then
            log_result "PASS" "  ✅ Audit rules configured ($RULE_COUNT rules)"
        else
            log_result "WARN" "  ⚠️  Limited audit rules ($RULE_COUNT rules)"
            if [ "$MODE" = "fix" ]; then
                # Add basic audit rules
                cat > /etc/audit/rules.d/hardening.rules << 'EOF'
# Log changes to system administration scope
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope

# Log sudo usage
-w /var/log/sudo.log -p wa -k actions

# Log date/time changes
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -k time-change

# Log network environment changes
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k network

# Log file deletion events
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k delete

# Log user/group changes
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity

# Log login/logout
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock/ -p wa -k logins

# Make configuration immutable
-e 2
EOF
                augenrules --load 2>/dev/null || service auditd restart
                log_result "INFO" "     🔧 Fixed: Added basic audit rules"
            fi
        fi
    else
        log_result "FAIL" "  ❌ No audit rules file found"
        if [ "$MODE" = "fix" ]; then
            mkdir -p /etc/audit/rules.d/
            log_result "INFO" "     🔧 Created audit rules directory"
        fi
    fi
    
    # Check audit log permissions
    if [ -d /var/log/audit ]; then
        AUDIT_PERMS=$(stat -c "%a" /var/log/audit)
        if [ "$AUDIT_PERMS" = "700" ]; then
            log_result "PASS" "  ✅ Audit log directory permissions correct"
        else
            log_result "FAIL" "  ❌ Audit log directory permissions incorrect ($AUDIT_PERMS)"
            if [ "$MODE" = "fix" ]; then
                chmod 700 /var/log/audit
                chown root:root /var/log/audit
                log_result "INFO" "     🔧 Fixed: Set audit log permissions"
            fi
        fi
    fi
    
else
    log_result "FAIL" "  ❌ Auditd not installed"
    if [ "$MODE" = "fix" ]; then
        apt-get install -y auditd audispd-plugins 2>/dev/null || yum install -y audit 2>/dev/null
        systemctl enable auditd
        systemctl start auditd
        log_result "INFO" "     🔧 Fixed: Installed and started auditd"
    fi
fi

# 8.5 Logrotate
echo -e "\n[8.5] Log Rotation..." | tee -a "$REPORT"

if command -v logrotate &>/dev/null; then
    log_result "PASS" "  ✅ Logrotate is installed"
    
    if [ -f /etc/logrotate.conf ]; then
        log_result "PASS" "  ✅ Logrotate configuration exists"
    else
        log_result "WARN" "  ⚠️  Logrotate configuration missing"
    fi
else
    log_result "FAIL" "  ❌ Logrotate not installed"
    if [ "$MODE" = "fix" ]; then
        apt-get install -y logrotate 2>/dev/null || yum install -y logrotate 2>/dev/null
        log_result "INFO" "     🔧 Fixed: Installed logrotate"
    fi
fi

# 8.6 AIDE (File Integrity)
echo -e "\n[8.6] File Integrity Checking (AIDE)..." | tee -a "$REPORT"

if command -v aide &>/dev/null; then
    log_result "PASS" "  ✅ AIDE is installed"
    
    # Check if AIDE database exists
    if [ -f /var/lib/aide/aide.db ] || [ -f /var/lib/aide/aide.db.gz ]; then
        log_result "PASS" "  ✅ AIDE database initialized"
    else
        log_result "WARN" "  ⚠️  AIDE database not initialized"
        if [ "$MODE" = "fix" ]; then
            log_result "INFO" "     ⚠️  Manual action: Run 'aideinit' to initialize AIDE"
        fi
    fi
    
    # Check for AIDE cron job
    if grep -qr "aide" /etc/cron.* /etc/crontab 2>/dev/null; then
        log_result "PASS" "  ✅ AIDE scheduled to run regularly"
    else
        log_result "WARN" "  ⚠️  AIDE not scheduled"
        if [ "$MODE" = "fix" ]; then
            echo "0 5 * * * root /usr/bin/aide --check" > /etc/cron.d/aide
            log_result "INFO" "     🔧 Fixed: Scheduled AIDE daily checks"
        fi
    fi
else
    log_result "WARN" "  ⚠️  AIDE not installed"
    if [ "$MODE" = "fix" ]; then
        apt-get install -y aide aide-common 2>/dev/null || yum install -y aide 2>/dev/null
        log_result "INFO" "     🔧 Fixed: Installed AIDE (run 'aideinit' to initialize)"
    fi
fi

# Summary
echo -e "\n================================================================" | tee -a "$REPORT"
echo "MODULE 8 SUMMARY: $PASSED passed, $FAILED failed/warnings" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

exit 0
