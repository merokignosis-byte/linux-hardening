#!/bin/bash
# Network Hardening - Annexure B Section 4

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
echo "MODULE 4: NETWORK HARDENING" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

# 4.1 Network Devices
echo -e "\n[4.1] Network Device Configuration..." | tee -a "$REPORT"

# Check wireless interfaces
if ls /sys/class/net/*/wireless 2>/dev/null | grep -q wireless; then
    log_result "FAIL" "  ❌ Wireless interfaces detected"
    if [ "$MODE" = "fix" ]; then
        for iface in $(ls /sys/class/net/*/wireless 2>/dev/null | cut -d'/' -f5); do
            ip link set "$iface" down 2>/dev/null
        done
        log_result "INFO" "     🔧 Fixed: Disabled wireless interfaces"
    fi
else
    log_result "PASS" "  ✅ No wireless interfaces detected"
fi

# Check Bluetooth
if systemctl is-enabled bluetooth 2>/dev/null | grep -q "enabled"; then
    log_result "FAIL" "  ❌ Bluetooth service is enabled"
    if [ "$MODE" = "fix" ]; then
        systemctl stop bluetooth
        systemctl disable bluetooth
        log_result "INFO" "     🔧 Fixed: Disabled bluetooth"
    fi
else
    log_result "PASS" "  ✅ Bluetooth service is disabled"
fi

# 4.2 Network Kernel Modules
echo -e "\n[4.2] Network Kernel Modules..." | tee -a "$REPORT"

NET_MODULES=("dccp" "tipc" "rds" "sctp")

for mod in "${NET_MODULES[@]}"; do
    if lsmod | grep -q "^$mod"; then
        log_result "FAIL" "  ❌ Network module $mod is loaded"
        if [ "$MODE" = "fix" ]; then
            echo "install $mod /bin/true" > "/etc/modprobe.d/$mod.conf"
            rmmod "$mod" 2>/dev/null
            log_result "INFO" "     🔧 Fixed: Disabled $mod"
        fi
    else
        if [ ! -f "/etc/modprobe.d/$mod.conf" ]; then
            log_result "WARN" "  ⚠️  Module $mod not blacklisted"
            if [ "$MODE" = "fix" ]; then
                echo "install $mod /bin/true" > "/etc/modprobe.d/$mod.conf"
                log_result "INFO" "     🔧 Fixed: Blacklisted $mod"
            fi
        else
            log_result "PASS" "  ✅ Module $mod properly disabled"
        fi
    fi
done

# 4.3 Network Kernel Parameters
echo -e "\n[4.3] Network Kernel Parameters..." | tee -a "$REPORT"

SYSCTL_PARAMS=(
    "net.ipv4.ip_forward:0:IP forwarding disabled"
    "net.ipv4.conf.all.send_redirects:0:Packet redirect sending disabled"
    "net.ipv4.conf.default.send_redirects:0:Default packet redirect disabled"
    "net.ipv4.icmp_ignore_bogus_error_responses:1:Bogus ICMP responses ignored"
    "net.ipv4.icmp_echo_ignore_broadcasts:1:Broadcast ICMP ignored"
    "net.ipv4.conf.all.accept_redirects:0:ICMP redirects not accepted"
    "net.ipv4.conf.default.accept_redirects:0:Default ICMP redirects disabled"
    "net.ipv4.conf.all.secure_redirects:0:Secure ICMP redirects disabled"
    "net.ipv4.conf.default.secure_redirects:0:Default secure redirects disabled"
    "net.ipv4.conf.all.rp_filter:1:Reverse path filtering enabled"
    "net.ipv4.conf.default.rp_filter:1:Default reverse path filtering enabled"
    "net.ipv4.conf.all.accept_source_route:0:Source routed packets disabled"
    "net.ipv4.conf.default.accept_source_route:0:Default source routing disabled"
    "net.ipv4.conf.all.log_martians:1:Suspicious packets logged"
    "net.ipv4.conf.default.log_martians:1:Default martian logging enabled"
    "net.ipv4.tcp_syncookies:1:TCP SYN cookies enabled"
    "net.ipv6.conf.all.accept_ra:0:IPv6 router advertisements disabled"
    "net.ipv6.conf.default.accept_ra:0:Default IPv6 RA disabled"
)

for param_info in "${SYSCTL_PARAMS[@]}"; do
    IFS=':' read -r param expected desc <<< "$param_info"
    
    current=$(sysctl -n "$param" 2>/dev/null)
    
    if [ "$current" = "$expected" ]; then
        log_result "PASS" "  ✅ $desc ($param=$expected)"
    else
        log_result "FAIL" "  ❌ $desc ($param=$current, expected $expected)"
        if [ "$MODE" = "fix" ]; then
            sysctl -w "$param=$expected" >/dev/null 2>&1
            
            # Make persistent
            CONF_FILE="/etc/sysctl.d/90-network-hardening.conf"
            if ! grep -q "^$param" "$CONF_FILE" 2>/dev/null; then
                echo "$param = $expected" >> "$CONF_FILE"
            else
                sed -i "s|^$param.*|$param = $expected|" "$CONF_FILE"
            fi
            
            log_result "INFO" "     🔧 Fixed: Set $param=$expected"
        fi
    fi
done

# Summary
echo -e "\n================================================================" | tee -a "$REPORT"
echo "MODULE 4 SUMMARY: $PASSED passed, $FAILED failed/warnings" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

exit 0
