#!/bin/bash
# Filesystem Hardening Script - Annexure B Section 1

MODE=${1:-scan}
REPORT=${2:-hardening_report.txt}
FAILED=0
PASSED=0

log_result() {
    local status=$1
    local message=$2
    echo "$message" | tee -a "$REPORT"
    if [ "$status" = "PASS" ]; then
        ((PASSED++))
    else
        ((FAILED++))
    fi
}

echo "================================================================" | tee -a "$REPORT"
echo "MODULE 1: FILESYSTEM HARDENING" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

# 1.1 Configure Filesystem Kernel Modules
echo -e "\n[1.1] Disabling Unused Filesystem Kernel Modules..." | tee -a "$REPORT"

MODULES=("cramfs" "freevxfs" "hfs" "hfsplus" "jffs2" "overlayfs" "squashfs" "udf" "usb-storage")

for mod in "${MODULES[@]}"; do
    if lsmod | grep -q "^$mod"; then
        log_result "FAIL" "  ❌ Module $mod is loaded"
        if [ "$MODE" = "fix" ]; then
            echo "install $mod /bin/true" > "/etc/modprobe.d/$mod.conf"
            echo "blacklist $mod" >> "/etc/modprobe.d/$mod.conf"
            rmmod "$mod" 2>/dev/null
            log_result "INFO" "     🔧 Fixed: Disabled $mod module"
        fi
    else
        if [ ! -f "/etc/modprobe.d/$mod.conf" ]; then
            log_result "WARN" "  ⚠️  Module $mod not blacklisted"
            if [ "$MODE" = "fix" ]; then
                echo "install $mod /bin/true" > "/etc/modprobe.d/$mod.conf"
                echo "blacklist $mod" >> "/etc/modprobe.d/$mod.conf"
                log_result "INFO" "     🔧 Fixed: Blacklisted $mod"
            fi
        else
            log_result "PASS" "  ✅ Module $mod properly disabled"
        fi
    fi
done

# 1.2 Configure Filesystem Partitions
echo -e "\n[1.2] Checking Filesystem Partition Configuration..." | tee -a "$REPORT"

check_partition_option() {
    local partition=$1
    local option=$2
    
    if findmnt -n "$partition" &>/dev/null; then
        if findmnt -n -o OPTIONS "$partition" | grep -q "$option"; then
            log_result "PASS" "  ✅ $partition has $option option"
        else
            log_result "FAIL" "  ❌ $partition missing $option option"
            if [ "$MODE" = "fix" ]; then
                # Add to fstab
                if grep -q "^[^#].*$partition" /etc/fstab; then
                    sed -i "\|$partition|s/defaults/defaults,$option/" /etc/fstab
                    mount -o remount "$partition" 2>/dev/null
                    log_result "INFO" "     🔧 Fixed: Added $option to $partition"
                fi
            fi
        fi
    else
        log_result "WARN" "  ⚠️  $partition is not a separate partition"
    fi
}

# Check /tmp
check_partition_option "/tmp" "nodev"
check_partition_option "/tmp" "nosuid"
check_partition_option "/tmp" "noexec"

# Check /dev/shm
check_partition_option "/dev/shm" "nodev"
check_partition_option "/dev/shm" "nosuid"
check_partition_option "/dev/shm" "noexec"

# Check /home
check_partition_option "/home" "nodev"
check_partition_option "/home" "nosuid"

# Check /var
check_partition_option "/var" "nodev"
check_partition_option "/var" "nosuid"

# Check /var/tmp
check_partition_option "/var/tmp" "nodev"
check_partition_option "/var/tmp" "nosuid"
check_partition_option "/var/tmp" "noexec"

# Check /var/log
check_partition_option "/var/log" "nodev"
check_partition_option "/var/log" "nosuid"
check_partition_option "/var/log" "noexec"

# Check /var/log/audit
check_partition_option "/var/log/audit" "nodev"
check_partition_option "/var/log/audit" "nosuid"
check_partition_option "/var/log/audit" "noexec"

# Summary
echo -e "\n================================================================" | tee -a "$REPORT"
echo "MODULE 1 SUMMARY: $PASSED passed, $FAILED failed/warnings" | tee -a "$REPORT"
echo "================================================================" | tee -a "$REPORT"

exit 0
