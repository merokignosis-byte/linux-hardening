#!/usr/bin/env python3
"""
Linux System Hardening Tool - Main Controller
Based on Security Annexure B Requirements
"""

import subprocess
import sys
import os
from datetime import datetime
import json

class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

class HardeningController:
    def __init__(self):
        self.modules = {
            '1': {'name': 'Filesystem Configuration', 'script': '1_filesystem.sh'},
            '2': {'name': 'Package Management', 'script': '2_package_mgmt.sh'},
            '3': {'name': 'Services Configuration', 'script': '3_services.sh'},
            '4': {'name': 'Network Configuration', 'script': '4_network.sh'},
            '5': {'name': 'Host Based Firewall', 'script': '5_firewall.sh'},
            '6': {'name': 'Access Control', 'script': '6_access_control.sh'},
            '7': {'name': 'User Accounts', 'script': '7_user_accounts.sh'},
            '8': {'name': 'Logging and Auditing', 'script': '8_logging_audit.sh'},
            '9': {'name': 'System Maintenance', 'script': '9_system_maintenance.sh'}
        }
        self.report_file = f"hardening_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        self.results = {}

    def print_banner(self):
        banner = f"""
{Colors.CYAN}{'='*70}
{Colors.BOLD}    LINUX SYSTEM HARDENING TOOL
{Colors.ENDC}{Colors.CYAN}    Based on Security Annexure B Requirements
{'='*70}{Colors.ENDC}
"""
        print(banner)

    def check_root(self):
        if os.geteuid() != 0:
            print(f"{Colors.RED}[ERROR] This script must be run as root!{Colors.ENDC}")
            sys.exit(1)

    def display_menu(self):
        print(f"\n{Colors.BOLD}Available Hardening Modules:{Colors.ENDC}")
        for key, module in self.modules.items():
            print(f"  {Colors.YELLOW}[{key}]{Colors.ENDC} {module['name']}")
        print(f"  {Colors.YELLOW}[A]{Colors.ENDC} Run All Modules")
        print(f"  {Colors.YELLOW}[S]{Colors.ENDC} Scan Only (No Fixes)")
        print(f"  {Colors.YELLOW}[Q]{Colors.ENDC} Quit")

    def run_script(self, script_name, scan_only=False):
        """Execute a bash script and capture output"""
        if not os.path.exists(script_name):
            return {'status': 'error', 'message': f'Script {script_name} not found'}
        
        # Make script executable
        os.chmod(script_name, 0o755)
        
        mode = 'scan' if scan_only else 'fix'
        print(f"\n{Colors.BLUE}[*] Running {script_name} in {mode} mode...{Colors.ENDC}")
        
        try:
            result = subprocess.run(
                ['bash', script_name, mode],
                capture_output=True,
                text=True,
                timeout=300
            )
            
            return {
                'status': 'success' if result.returncode == 0 else 'warning',
                'stdout': result.stdout,
                'stderr': result.stderr,
                'returncode': result.returncode
            }
        except subprocess.TimeoutExpired:
            return {'status': 'error', 'message': 'Script execution timed out'}
        except Exception as e:
            return {'status': 'error', 'message': str(e)}

    def generate_report(self):
        """Generate comprehensive hardening report"""
        print(f"\n{Colors.CYAN}[*] Generating report: {self.report_file}{Colors.ENDC}")
        
        with open(self.report_file, 'w') as f:
            f.write("="*70 + "\n")
            f.write("LINUX SYSTEM HARDENING REPORT\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write("="*70 + "\n\n")
            
            for module_id, result in self.results.items():
                module_name = self.modules[module_id]['name']
                f.write(f"\n{'='*70}\n")
                f.write(f"MODULE {module_id}: {module_name}\n")
                f.write(f"{'='*70}\n")
                f.write(f"Status: {result['status']}\n")
                f.write(f"Return Code: {result.get('returncode', 'N/A')}\n\n")
                f.write("OUTPUT:\n")
                f.write("-"*70 + "\n")
                f.write(result.get('stdout', 'No output'))
                f.write("\n")
                
                if result.get('stderr'):
                    f.write("\nERRORS/WARNINGS:\n")
                    f.write("-"*70 + "\n")
                    f.write(result['stderr'])
                    f.write("\n")
        
        print(f"{Colors.GREEN}[✓] Report saved to: {self.report_file}{Colors.ENDC}")

    def run_all_modules(self, scan_only=False):
        """Run all hardening modules"""
        mode_text = "SCAN" if scan_only else "HARDENING"
        print(f"\n{Colors.BOLD}Starting {mode_text} process for all modules...{Colors.ENDC}")
        
        for module_id, module_info in self.modules.items():
            print(f"\n{Colors.CYAN}{'='*70}")
            print(f"MODULE {module_id}: {module_info['name']}")
            print(f"{'='*70}{Colors.ENDC}")
            
            result = self.run_script(module_info['script'], scan_only)
            self.results[module_id] = result
            
            # Display result summary
            if result['status'] == 'success':
                print(f"{Colors.GREEN}[✓] Module completed successfully{Colors.ENDC}")
            elif result['status'] == 'warning':
                print(f"{Colors.YELLOW}[!] Module completed with warnings{Colors.ENDC}")
            else:
                print(f"{Colors.RED}[✗] Module failed: {result.get('message', 'Unknown error')}{Colors.ENDC}")
        
        self.generate_report()

    def run_single_module(self, module_id, scan_only=False):
        """Run a single hardening module"""
        if module_id not in self.modules:
            print(f"{Colors.RED}[ERROR] Invalid module selection{Colors.ENDC}")
            return
        
        module_info = self.modules[module_id]
        print(f"\n{Colors.CYAN}{'='*70}")
        print(f"MODULE {module_id}: {module_info['name']}")
        print(f"{'='*70}{Colors.ENDC}")
        
        result = self.run_script(module_info['script'], scan_only)
        self.results[module_id] = result
        
        # Display output
        print(result.get('stdout', ''))
        if result.get('stderr'):
            print(f"\n{Colors.YELLOW}Warnings/Errors:{Colors.ENDC}")
            print(result['stderr'])
        
        self.generate_report()

    def run(self):
        """Main execution loop"""
        self.print_banner()
        self.check_root()
        
        while True:
            self.display_menu()
            choice = input(f"\n{Colors.BOLD}Select option: {Colors.ENDC}").strip().upper()
            
            if choice == 'Q':
                print(f"\n{Colors.CYAN}Exiting...{Colors.ENDC}")
                break
            elif choice == 'A':
                confirm = input(f"{Colors.YELLOW}Run ALL modules with FIX mode? (yes/no): {Colors.ENDC}").strip().lower()
                if confirm == 'yes':
                    self.run_all_modules(scan_only=False)
                else:
                    print(f"{Colors.RED}Cancelled.{Colors.ENDC}")
            elif choice == 'S':
                self.run_all_modules(scan_only=True)
            elif choice in self.modules:
                mode = input(f"{Colors.YELLOW}Mode - [S]can or [F]ix? (s/f): {Colors.ENDC}").strip().lower()
                scan_mode = mode == 's'
                self.run_single_module(choice, scan_only=scan_mode)
            else:
                print(f"{Colors.RED}[ERROR] Invalid selection{Colors.ENDC}")

if __name__ == "__main__":
    controller = HardeningController()
    controller.run()
