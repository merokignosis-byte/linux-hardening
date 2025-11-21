#!/bin/bash
# Host-Based Firewall Configuration - Annexure B Section 5

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
echo "MODULE 5: HOST-BASED FIREWALL" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

# 5.1 UFW Configuration (for Debian/Ubuntu)
echo -e "\n[5.1] Checking UFW Firewall..." | tee -a "$REPORT"

if command -v ufw &>/dev/null; then
    # Check if ufw is installed
    log_result "PASS" "  ✅ UFW is installed"
    
    # Check if enabled
    if ufw status | grep -q "Status: active"; then
        log_result "PASS" "  ✅ UFW is enabled and active"
    else
        log_result "FAIL" "  ❌ UFW is not active"
        if [ "$MODE" = "fix" ]; then
            ufw --force enable
            log_result "INFO" "     🔧 Fixed: Enabled UFW"
        fi
    fi
    
    # Check default policies
    DEFAULT_IN=$(ufw status verbose | grep "Default:" | grep -o "deny (incoming)")
    DEFAULT_OUT=$(ufw status verbose | grep "Default:" | grep -o "allow (outgoing)")
    
    if [ -n "$DEFAULT_IN" ]; then
        log_result "PASS" "  ✅ UFW default deny incoming"
    else
        log_result "FAIL" "  ❌ UFW default policy for incoming not deny"
        if [ "$MODE" = "fix" ]; then
            ufw default deny incoming
            log_result "INFO" "     🔧 Fixed: Set default deny incoming"
        fi
    fi
    
    if [ -n "$DEFAULT_OUT" ]; then
        log_result "PASS" "  ✅ UFW default allow outgoing"
    else
        log_result "WARN" "  ⚠️  UFW default policy for outgoing not allow"
        if [ "$MODE" = "fix" ]; then
            ufw default allow outgoing
            log_result "INFO" "     🔧 Fixed: Set default allow outgoing"
        fi
    fi
    
    # Check loopback
    if ufw status | grep -q "ALLOW.*Anywhere on lo"; then
        log_result "PASS" "  ✅ UFW loopback configured"
    else
        log_result "FAIL" "  ❌ UFW loopback not configured"
        if [ "$MODE" = "fix" ]; then
            ufw allow in on lo
            ufw deny in from 127.0.0.0/8
            ufw deny in from ::1
            log_result "INFO" "     🔧 Fixed: Configured loopback"
        fi
    fi
    
else
    log_result "WARN" "  ⚠️  UFW not installed (checking iptables)"
    
    # Check iptables
    if command -v iptables &>/dev/null; then
        if iptables -L -n | grep -q "Chain INPUT"; then
            log_result "PASS" "  ✅ iptables is available"
            
            # Check if any rules exist
            RULE_COUNT=$(iptables -L INPUT -n | grep -c "^")
            if [ "$RULE_COUNT" -gt 3 ]; then
                log_result "PASS" "  ✅ iptables has rules configured"
            else
                log_result "WARN" "  ⚠️  iptables has minimal rules"
            fi
        fi
    else
        log_result "FAIL" "  ❌ No firewall detected (neither UFW nor iptables)"
        if [ "$MODE" = "fix" ]; then
            log_result "INFO" "     ⚠️  Manual action: Install ufw or configure iptables"
        fi
    fi
fi

# 5.2 Check iptables-persistent conflicts
if command -v ufw &>/dev/null; then
    if dpkg -l | grep -q iptables-persistent; then
        log_result "FAIL" "  ❌ iptables-persistent conflicts with UFW"
        if [ "$MODE" = "fix" ]; then
            apt-get remove -y iptables-persistent 2>/dev/null
            log_result "INFO" "     🔧 Fixed: Removed iptables-persistent"
        fi
    else
        log_result "PASS" "  ✅ No iptables-persistent conflict"
    fi
fi

# Summary
echo -e "\n================================================================" | tee -a "$REPORT"
echo "MODULE 5 SUMMARY: $PASSED passed, $FAILED failed/warnings" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

exit 0
