#!/bin/bash
# System Maintenance - Annexure B Section 9

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
echo "MODULE 9: SYSTEM MAINTENANCE" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

# 9.1 System File Permissions
echo -e "\n[9.1] Critical System File Permissions..." | tee -a "$REPORT"

CRITICAL_FILES=(
    "/etc/passwd:644:root:root:passwd file"
    "/etc/passwd-:600:root:root:passwd backup"
    "/etc/group:644:root:root:group file"
    "/etc/group-:600:root:root:group backup"
    "/etc/shadow:000:root:shadow:shadow file"
    "/etc/shadow-:000:root:shadow:shadow backup"
    "/etc/gshadow:000:root:shadow:gshadow file"
    "/etc/gshadow-:000:root:shadow:gshadow backup"
    "/etc/shells:644:root:root:shells file"
)

for file_info in "${CRITICAL_FILES[@]}"; do
    IFS=':' read -r file expected_perms expected_owner expected_group desc <<< "$file_info"
    
    if [ -f "$file" ]; then
        # Check permissions
        PERMS=$(stat -c "%a" "$file")
        OWNER=$(stat -c "%U" "$file")
        GROUP=$(stat -c "%G" "$file")
        
        if [ "$PERMS" = "$expected_perms" ] && [ "$OWNER" = "$expected_owner" ] && \
           [ "$GROUP" = "$expected_group" ]; then
            log_result "PASS" "  ✅ $desc properly configured ($PERMS $OWNER:$GROUP)"
        else
            log_result "FAIL" "  ❌ $desc incorrect ($PERMS $OWNER:$GROUP, expected $expected_perms $expected_owner:$expected_group)"
            if [ "$MODE" = "fix" ]; then
                chmod "$expected_perms" "$file"
                chown "$expected_owner:$expected_group" "$file"
                log_result "INFO" "     🔧 Fixed: Set $file to $expected_perms $expected_owner:$expected_group"
            fi
        fi
    else
        log_result "WARN" "  ⚠️  $desc not found"
    fi
done

# Check /etc/security/opasswd
if [ -f /etc/security/opasswd ]; then
    OPASSWD_PERMS=$(stat -c "%a" /etc/security/opasswd)
    if [ "$OPASSWD_PERMS" = "600" ]; then
        log_result "PASS" "  ✅ opasswd permissions correct"
    else
        log_result "FAIL" "  ❌ opasswd permissions incorrect ($OPASSWD_PERMS)"
        if [ "$MODE" = "fix" ]; then
            chmod 600 /etc/security/opasswd
            chown root:root /etc/security/opasswd
            log_result "INFO" "     🔧 Fixed: Set opasswd permissions"
        fi
    fi
fi

# 9.2 World-Writable Files
echo -e "\n[9.2] Checking World-Writable Files..." | tee -a "$REPORT"

WORLD_WRITABLE=$(find / -xdev -type f -perm -0002 -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null | head -10)

if [ -z "$WORLD_WRITABLE" ]; then
    log_result "PASS" "  ✅ No world-writable files found"
else
    WW_COUNT=$(echo "$WORLD_WRITABLE" | wc -l)
    log_result "WARN" "  ⚠️  Found $WW_COUNT world-writable files"
    if [ "$MODE" = "fix" ]; then
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                chmod o-w "$file"
            fi
        done <<< "$WORLD_WRITABLE"
        log_result "INFO" "     🔧 Fixed: Removed world-write permissions"
    fi
fi

# 9.3 Files Without Owner
echo -e "\n[9.3] Checking Unowned Files..." | tee -a "$REPORT"

UNOWNED=$(find / -xdev -nouser -o -nogroup -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null | head -10)

if [ -z "$UNOWNED" ]; then
    log_result "PASS" "  ✅ No unowned files found"
else
    UNOWNED_COUNT=$(echo "$UNOWNED" | wc -l)
    log_result "WARN" "  ⚠️  Found $UNOWNED_COUNT unowned files/directories"
    if [ "$MODE" = "fix" ]; then
        log_result "INFO" "     ⚠️  Manual review required for unowned files"
    fi
fi

# 9.4 SUID/SGID Files
echo -e "\n[9.4] Auditing SUID/SGID Files..." | tee -a "$REPORT"

SUID_FILES=$(find / -xdev -type f -perm -4000 -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null | wc -l)
SGID_FILES=$(find / -xdev -type f -perm -2000 -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null | wc -l)

log_result "INFO" "  ℹ️  Found $SUID_FILES SUID files and $SGID_FILES SGID files"
log_result "INFO" "  ℹ️  Review these files regularly for security"

# 9.5 Password and Group File Consistency
echo -e "\n[9.5] Password and Group Consistency..." | tee -a "$REPORT"

# Check shadow passwords
if awk -F: '$2 != "x" {exit 1}' /etc/passwd; then
    log_result "PASS" "  ✅ All accounts use shadowed passwords"
else
    log_result "FAIL" "  ❌ Some accounts not using shadow passwords"
    if [ "$MODE" = "fix" ]; then
        pwconv
        log_result "INFO" "     🔧 Fixed: Converted to shadow passwords"
    fi
fi

# Check empty password fields
EMPTY_PASS=$(awk -F: '$2 == "" {print $1}' /etc/shadow)
if [ -z "$EMPTY_PASS" ]; then
    log_result "PASS" "  ✅ No empty password fields in shadow"
else
    log_result "FAIL" "  ❌ Accounts with empty passwords: $EMPTY_PASS"
    if [ "$MODE" = "fix" ]; then
        for user in $EMPTY_PASS; do
            passwd -l "$user"
        done
        log_result "INFO" "     🔧 Fixed: Locked accounts with empty passwords"
    fi
fi

# Check all groups in passwd exist in group
MISSING_GROUPS=""
while IFS=: read -r user x uid gid rest; do
    if ! grep -q "^[^:]*:[^:]*:$gid:" /etc/group; then
        MISSING_GROUPS="$MISSING_GROUPS $user(GID:$gid)"
    fi
done < /etc/passwd

if [ -z "$MISSING_GROUPS" ]; then
    log_result "PASS" "  ✅ All groups in passwd exist in group file"
else
    log_result "FAIL" "  ❌ Users with missing groups:$MISSING_GROUPS"
fi

# Check shadow group
SHADOW_GROUP_USERS=$(awk -F: '$1 == "shadow" {print $4}' /etc/group)
if [ -z "$SHADOW_GROUP_USERS" ]; then
    log_result "PASS" "  ✅ Shadow group is empty"
else
    log_result "WARN" "  ⚠️  Shadow group has users: $SHADOW_GROUP_USERS"
fi

# 9.6 User Home Directories
echo -e "\n[9.6] User Home Directory Security..." | tee -a "$REPORT"

HOME_ISSUES=0

while IFS=: read -r user x uid gid gecos home shell; do
    # Skip system accounts and special users
    if [ "$uid" -ge 1000 ] && [ "$user" != "nobody" ] && [ "$user" != "nfsnobody" ]; then
        if [ ! -d "$home" ]; then
            ((HOME_ISSUES++))
            continue
        fi
        
        # Check home directory permissions
        HOME_PERMS=$(stat -c "%a" "$home" 2>/dev/null)
        if [ "$HOME_PERMS" -gt 750 ] 2>/dev/null; then
            ((HOME_ISSUES++))
            if [ "$MODE" = "fix" ]; then
                chmod 750 "$home"
            fi
        fi
        
        # Check ownership
        HOME_OWNER=$(stat -c "%U" "$home" 2>/dev/null)
        if [ "$HOME_OWNER" != "$user" ]; then
            ((HOME_ISSUES++))
            if [ "$MODE" = "fix" ]; then
                chown "$user:$user" "$home"
            fi
        fi
        
        # Check dot files
        if [ -d "$home" ]; then
            find "$home" -maxdepth 1 -name ".*" -type f 2>/dev/null | while read -r dotfile; do
                DOT_PERMS=$(stat -c "%a" "$dotfile" 2>/dev/null)
                if [ "$DOT_PERMS" -gt 600 ] 2>/dev/null; then
                    if [ "$MODE" = "fix" ]; then
                        chmod 600 "$dotfile"
                    fi
                fi
            done
        fi
    fi
done < /etc/passwd

if [ "$HOME_ISSUES" -eq 0 ]; then
    log_result "PASS" "  ✅ User home directories properly configured"
else
    log_result "WARN" "  ⚠️  Found $HOME_ISSUES home directory issues"
    if [ "$MODE" = "fix" ]; then
        log_result "INFO" "     🔧 Fixed: Corrected home directory permissions"
    fi
fi

# 9.7 Final Security Checks
echo -e "\n[9.7] Additional Security Checks..." | tee -a "$REPORT"

# Check for .rhosts files
RHOSTS_FILES=$(find /home -name ".rhosts" 2>/dev/null)
if [ -z "$RHOSTS_FILES" ]; then
    log_result "PASS" "  ✅ No .rhosts files found"
else
    log_result "WARN" "  ⚠️  .rhosts files detected"
    if [ "$MODE" = "fix" ]; then
        find /home -name ".rhosts" -delete 2>/dev/null
        log_result "INFO" "     🔧 Fixed: Removed .rhosts files"
    fi
fi

# Check for .netrc files
NETRC_FILES=$(find /home -name ".netrc" 2>/dev/null)
if [ -z "$NETRC_FILES" ]; then
    log_result "PASS" "  ✅ No .netrc files found"
else
    log_result "WARN" "  ⚠️  .netrc files detected (may contain passwords)"
fi

# Summary
echo -e "\n================================================================" | tee -a "$REPORT"
echo "MODULE 9 SUMMARY: $PASSED passed, $FAILED failed/warnings" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

exit 0
