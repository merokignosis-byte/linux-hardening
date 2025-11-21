#!/bin/bash
# Services Configuration - Annexure B Section 3

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
echo "MODULE 3: SERVICES CONFIGURATION" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

# 3.1 Disable Unnecessary Server Services
echo -e "\n[3.1] Checking Server Services..." | tee -a "$REPORT"

SERVICES=(
    "autofs:autofs"
    "avahi-daemon:avahi"
    "isc-dhcp-server:dhcpd"
    "bind9:named"
    "dnsmasq:dnsmasq"
    "vsftpd:ftp"
    "slapd:ldap"
    "dovecot:imap"
    "nfs-server:nfs"
    "ypserv:nis"
    "cups:printing"
    "rpcbind:rpc"
    "rsync:rsync"
    "smbd:samba"
    "snmpd:snmp"
    "tftpd:tftp"
    "squid:proxy"
    "apache2:web|nginx:web|httpd:web"
    "xinetd:xinetd"
)

check_service() {
    local service=$1
    local desc=$2
    
    if systemctl is-enabled "$service" 2>/dev/null | grep -q "enabled"; then
        log_result "FAIL" "  ❌ $desc service ($service) is enabled"
        if [ "$MODE" = "fix" ]; then
            systemctl stop "$service" 2>/dev/null
            systemctl disable "$service" 2>/dev/null
            log_result "INFO" "     🔧 Fixed: Disabled $service"
        fi
    elif systemctl list-unit-files | grep -q "^$service"; then
        log_result "PASS" "  ✅ $desc service ($service) is disabled"
    else
        log_result "PASS" "  ✅ $desc service ($service) not installed"
    fi
}

for svc_info in "${SERVICES[@]}"; do
    IFS=':' read -r service desc <<< "$svc_info"
    check_service "$service" "$desc"
done

# Check X Window System
if systemctl list-unit-files | grep -q "graphical.target"; then
    TARGET=$(systemctl get-default)
    if [ "$TARGET" = "graphical.target" ]; then
        log_result "WARN" "  ⚠️  X Window System is enabled (graphical target)"
        if [ "$MODE" = "fix" ]; then
            systemctl set-default multi-user.target
            log_result "INFO" "     🔧 Fixed: Set default to multi-user.target"
        fi
    else
        log_result "PASS" "  ✅ X Window System properly disabled"
    fi
fi

# 3.2 Client Services
echo -e "\n[3.2] Checking Client Services..." | tee -a "$REPORT"

CLIENT_PKGS=("nis" "rsh-client" "talk" "telnet" "openldap-clients" "ftp")

for pkg in "${CLIENT_PKGS[@]}"; do
    if dpkg -l | grep -qw "$pkg" 2>/dev/null || rpm -q "$pkg" &>/dev/null; then
        log_result "FAIL" "  ❌ Client package $pkg is installed"
        if [ "$MODE" = "fix" ]; then
            apt-get remove -y "$pkg" 2>/dev/null || yum remove -y "$pkg" 2>/dev/null
            log_result "INFO" "     🔧 Fixed: Removed $pkg"
        fi
    else
        log_result "PASS" "  ✅ Client package $pkg not installed"
    fi
done

# 3.3 Time Synchronization
echo -e "\n[3.3] Time Synchronization..." | tee -a "$REPORT"

if systemctl is-active systemd-timesyncd &>/dev/null; then
    log_result "PASS" "  ✅ systemd-timesyncd is active"
    
    if grep -q "^NTP=" /etc/systemd/timesyncd.conf; then
        log_result "PASS" "  ✅ NTP servers configured"
    else
        log_result "WARN" "  ⚠️  No NTP servers configured"
        if [ "$MODE" = "fix" ]; then
            echo "NTP=time.nist.gov" >> /etc/systemd/timesyncd.conf
            systemctl restart systemd-timesyncd
            log_result "INFO" "     🔧 Fixed: Configured NTP server"
        fi
    fi
elif systemctl is-active chronyd &>/dev/null; then
    log_result "PASS" "  ✅ chrony is active"
    
    if grep -q "^server\|^pool" /etc/chrony/chrony.conf 2>/dev/null || \
       grep -q "^server\|^pool" /etc/chrony.conf 2>/dev/null; then
        log_result "PASS" "  ✅ NTP servers configured in chrony"
    else
        log_result "WARN" "  ⚠️  No NTP servers in chrony"
    fi
else
    log_result "FAIL" "  ❌ No time synchronization service running"
    if [ "$MODE" = "fix" ]; then
        systemctl enable systemd-timesyncd
        systemctl start systemd-timesyncd
        log_result "INFO" "     🔧 Fixed: Enabled systemd-timesyncd"
    fi
fi

# 3.4 Job Schedulers (Cron)
echo -e "\n[3.4] Cron Configuration..." | tee -a "$REPORT"

if systemctl is-enabled cron 2>/dev/null | grep -q "enabled"; then
    log_result "PASS" "  ✅ Cron daemon is enabled"
else
    log_result "FAIL" "  ❌ Cron daemon not enabled"
    if [ "$MODE" = "fix" ]; then
        systemctl enable cron 2>/dev/null || systemctl enable crond 2>/dev/null
        log_result "INFO" "     🔧 Fixed: Enabled cron"
    fi
fi

CRON_FILES=("/etc/crontab" "/etc/cron.hourly" "/etc/cron.daily" "/etc/cron.weekly" "/etc/cron.monthly" "/etc/cron.d")

for cfile in "${CRON_FILES[@]}"; do
    if [ -e "$cfile" ]; then
        PERMS=$(stat -c "%a" "$cfile")
        if [ "$PERMS" = "600" ] || [ "$PERMS" = "700" ]; then
            log_result "PASS" "  ✅ $cfile permissions correct ($PERMS)"
        else
            log_result "FAIL" "  ❌ $cfile permissions incorrect ($PERMS)"
            if [ "$MODE" = "fix" ]; then
                chmod 600 "$cfile"
                chown root:root "$cfile"
                log_result "INFO" "     🔧 Fixed: Set $cfile permissions"
            fi
        fi
    fi
done

# Restrict cron to authorized users
if [ ! -f /etc/cron.allow ]; then
    log_result "WARN" "  ⚠️  /etc/cron.allow not configured"
    if [ "$MODE" = "fix" ]; then
        echo "root" > /etc/cron.allow
        chmod 600 /etc/cron.allow
        rm -f /etc/cron.deny
        log_result "INFO" "     🔧 Fixed: Created /etc/cron.allow"
    fi
fi

# Summary
echo -e "\n================================================================" | tee -a "$REPORT"
echo "MODULE 3 SUMMARY: $PASSED passed, $FAILED failed/warnings" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

exit 0
