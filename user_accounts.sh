#!/bin/bash
# User Accounts & Environment - Annexure B Section 7

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
echo "MODULE 7: USER ACCOUNTS & ENVIRONMENT" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

# 7.1 Shadow Password Suite Parameters
echo -e "\n[7.1] Password Aging Configuration..." | tee -a "$REPORT"

LOGIN_DEFS="/etc/login.defs"

if [ -f "$LOGIN_DEFS" ]; then
    # PASS_MAX_DAYS
    MAX_DAYS=$(grep "^PASS_MAX_DAYS" "$LOGIN_DEFS" | awk '{print $2}')
    if [ "$MAX_DAYS" -le 90 ] && [ "$MAX_DAYS" -gt 0 ] 2>/dev/null; then
        log_result "PASS" "  ✅ Password expiration set to $MAX_DAYS days"
    else
        log_result "FAIL" "  ❌ Password expiration not configured properly (current: $MAX_DAYS)"
        if [ "$MODE" = "fix" ]; then
            sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' "$LOGIN_DEFS"
            log_result "INFO" "     🔧 Fixed: Set PASS_MAX_DAYS to 90"
        fi
    fi
    
    # PASS_MIN_DAYS
    MIN_DAYS=$(grep "^PASS_MIN_DAYS" "$LOGIN_DEFS" | awk '{print $2}')
    if [ "$MIN_DAYS" -ge 1 ] 2>/dev/null; then
        log_result "PASS" "  ✅ Minimum password days set to $MIN_DAYS"
    else
        log_result "FAIL" "  ❌ Minimum password days not configured (current: $MIN_DAYS)"
        if [ "$MODE" = "fix" ]; then
            sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' "$LOGIN_DEFS"
            log_result "INFO" "     🔧 Fixed: Set PASS_MIN_DAYS to 1"
        fi
    fi
    
    # PASS_WARN_AGE
    WARN_AGE=$(grep "^PASS_WARN_AGE" "$LOGIN_DEFS" | awk '{print $2}')
    if [ "$WARN_AGE" -ge 7 ] 2>/dev/null; then
        log_result "PASS" "  ✅ Password warning age set to $WARN_AGE days"
    else
        log_result "FAIL" "  ❌ Password warning age not configured (current: $WARN_AGE)"
        if [ "$MODE" = "fix" ]; then
            sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   7/' "$LOGIN_DEFS"
            log_result "INFO" "     🔧 Fixed: Set PASS_WARN_AGE to 7"
        fi
    fi
    
    # Password hashing algorithm
    if grep -qE "^ENCRYPT_METHOD.*SHA512" "$LOGIN_DEFS"; then
        log_result "PASS" "  ✅ Strong password hashing (SHA512)"
    else
        log_result "FAIL" "  ❌ Password hashing not SHA512"
        if [ "$MODE" = "fix" ]; then
            sed -i 's/^ENCRYPT_METHOD.*/ENCRYPT_METHOD SHA512/' "$LOGIN_DEFS"
            log_result "INFO" "     🔧 Fixed: Set ENCRYPT_METHOD to SHA512"
        fi
    fi
    
    # Inactive password lock
    INACTIVE=$(useradd -D | grep INACTIVE | cut -d= -f2)
    if [ "$INACTIVE" -le 30 ] && [ "$INACTIVE" -ge 0 ] 2>/dev/null; then
        log_result "PASS" "  ✅ Inactive password lock set to $INACTIVE days"
    else
        log_result "FAIL" "  ❌ Inactive password lock not configured"
        if [ "$MODE" = "fix" ]; then
            useradd -D -f 30
            log_result "INFO" "     🔧 Fixed: Set inactive lock to 30 days"
        fi
    fi
fi

# 7.2 Root Account Configuration
echo -e "\n[7.2] Root Account Security..." | tee -a "$REPORT"

# Check UID 0 accounts
UID_0_ACCOUNTS=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
if [ "$UID_0_ACCOUNTS" = "root" ]; then
    log_result "PASS" "  ✅ Only root has UID 0"
else
    log_result "FAIL" "  ❌ Multiple UID 0 accounts: $UID_0_ACCOUNTS"
fi

# Check GID 0 accounts
GID_0_ACCOUNTS=$(awk -F: '$4 == 0 {print $1}' /etc/passwd)
if [ "$GID_0_ACCOUNTS" = "root" ]; then
    log_result "PASS" "  ✅ Only root has GID 0"
else
    log_result "WARN" "  ⚠️  Multiple GID 0 accounts: $GID_0_ACCOUNTS"
fi

# Root umask
if grep -qE "^umask.*0[02]7" /root/.bashrc /root/.bash_profile 2>/dev/null || \
   grep -qE "^umask.*0[02]7" /etc/profile /etc/bash.bashrc 2>/dev/null; then
    log_result "PASS" "  ✅ Root umask properly configured"
else
    log_result "WARN" "  ⚠️  Root umask not configured"
    if [ "$MODE" = "fix" ]; then
        echo "umask 027" >> /root/.bashrc
        log_result "INFO" "     🔧 Fixed: Set root umask to 027"
    fi
fi

# 7.3 System Account Security
echo -e "\n[7.3] System Accounts..." | tee -a "$REPORT"

# Check system accounts have nologin shell
SYSTEM_ACCOUNTS=$(awk -F: '$3 < 1000 && $1 != "root" {print $1":"$7}' /etc/passwd)
INVALID_SHELLS=0

while IFS=: read -r user shell; do
    if [[ "$shell" != "/usr/sbin/nologin" && "$shell" != "/sbin/nologin" && "$shell" != "/bin/false" ]]; then
        ((INVALID_SHELLS++))
        if [ "$MODE" = "fix" ]; then
            usermod -s /usr/sbin/nologin "$user" 2>/dev/null
        fi
    fi
done <<< "$SYSTEM_ACCOUNTS"

if [ "$INVALID_SHELLS" -eq 0 ]; then
    log_result "PASS" "  ✅ All system accounts have proper shells"
else
    log_result "FAIL" "  ❌ $INVALID_SHELLS system accounts with invalid shells"
    if [ "$MODE" = "fix" ]; then
        log_result "INFO" "     🔧 Fixed: Updated system account shells"
    fi
fi

# 7.4 User Environment
echo -e "\n[7.4] User Environment Configuration..." | tee -a "$REPORT"

# Check default umask
if grep -qE "^umask.*0[02][27]" /etc/profile /etc/bash.bashrc /etc/login.defs 2>/dev/null; then
    log_result "PASS" "  ✅ Default umask properly configured"
else
    log_result "FAIL" "  ❌ Default umask not configured"
    if [ "$MODE" = "fix" ]; then
        echo "umask 027" >> /etc/profile.d/umask.sh
        chmod 644 /etc/profile.d/umask.sh
        log_result "INFO" "     🔧 Fixed: Set default umask to 027"
    fi
fi

# Check shell timeout
if grep -qE "^TMOUT=" /etc/profile /etc/bash.bashrc 2>/dev/null; then
    log_result "PASS" "  ✅ Shell timeout configured"
else
    log_result "WARN" "  ⚠️  Shell timeout not configured"
    if [ "$MODE" = "fix" ]; then
        echo "TMOUT=900" >> /etc/profile.d/timeout.sh
        echo "readonly TMOUT" >> /etc/profile.d/timeout.sh
        echo "export TMOUT" >> /etc/profile.d/timeout.sh
        chmod 644 /etc/profile.d/timeout.sh
        log_result "INFO" "     🔧 Fixed: Set shell timeout to 900 seconds"
    fi
fi

# Check nologin in /etc/shells
if grep -q "/usr/sbin/nologin\|/sbin/nologin" /etc/shells 2>/dev/null; then
    log_result "FAIL" "  ❌ nologin listed in /etc/shells"
    if [ "$MODE" = "fix" ]; then
        sed -i '/nologin/d' /etc/shells
        log_result "INFO" "     🔧 Fixed: Removed nologin from /etc/shells"
    fi
else
    log_result "PASS" "  ✅ nologin not in /etc/shells"
fi

# 7.5 Check for Duplicate UIDs/GIDs
echo -e "\n[7.5] Checking for Duplicates..." | tee -a "$REPORT"

# Duplicate UIDs
DUP_UIDS=$(cut -f3 -d":" /etc/passwd | sort -n | uniq -c | awk '$1 > 1 {print $2}')
if [ -z "$DUP_UIDS" ]; then
    log_result "PASS" "  ✅ No duplicate UIDs"
else
    log_result "FAIL" "  ❌ Duplicate UIDs found: $DUP_UIDS"
fi

# Duplicate GIDs
DUP_GIDS=$(cut -f3 -d":" /etc/group | sort -n | uniq -c | awk '$1 > 1 {print $2}')
if [ -z "$DUP_GIDS" ]; then
    log_result "PASS" "  ✅ No duplicate GIDs"
else
    log_result "FAIL" "  ❌ Duplicate GIDs found: $DUP_GIDS"
fi

# Duplicate usernames
DUP_USERS=$(cut -f1 -d":" /etc/passwd | sort | uniq -c | awk '$1 > 1 {print $2}')
if [ -z "$DUP_USERS" ]; then
    log_result "PASS" "  ✅ No duplicate usernames"
else
    log_result "FAIL" "  ❌ Duplicate usernames: $DUP_USERS"
fi

# Summary
echo -e "\n================================================================" | tee -a "$REPORT"
echo "MODULE 7 SUMMARY: $PASSED passed, $FAILED failed/warnings" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

exit 0
