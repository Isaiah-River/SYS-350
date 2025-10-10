#!/usr/bin/env python3
"""
vCenter VM Manager - Milestone 4.1
Based on: https://github.com/vmware/pyvmomi-community-samples
"""

import json
import re
import ssl
import getpass
import atexit
from pyVim.connect import SmartConnect, Disconnect
from pyVmomi import vim, vmodl


class VCenterManager:
    def __init__(self):
        self.si = None
        self.content = None
        self.vcenter_host = None
        self.username = None
        
    def load_config(self):
        """Requirement 1: Read username and vcenter hostname from file"""
        try:
            with open('vcenter_config.json', 'r') as f:
                config = json.load(f)
                self.vcenter_host = config['vcenter_host']
                self.username = config['username']
                return True
        except FileNotFoundError:
            print("Error: vcenter_config.json not found!")
            sample = {
                "vcenter_host": "vcenter.yourname.local",
                "username": "administrator@vsphere.local"
            }
            with open('vcenter_config.json', 'w') as f:
                json.dump(sample, f, indent=4)
            print("Created sample config. Please edit and run again.")
            return False
            
    def connect(self):
        """
        Based on: hello_world_vcenter.py
        Simple connection without tools module
        """
        password = getpass.getpass(f"Password for {self.username}: ")
        
        # Disable SSL verification for lab environment
        context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
        context.verify_mode = ssl.CERT_NONE
        
        try:
            self.si = SmartConnect(
                host=self.vcenter_host,
                user=self.username,
                pwd=password,
                sslContext=context
            )
            atexit.register(Disconnect, self.si)
            self.content = self.si.RetrieveContent()
            print(f"\nConnected to {self.vcenter_host}")
            return True
        except Exception as e:
            print(f"Connection failed: {e}")
            return False
            
    def get_session_info(self):
        """
        Requirement 2: Get current session information
        Based on: sessions_list.py (lines 34, 37-42)
        """
        session = self.si.content.sessionManager.currentSession
        
        info = {
            'username': session.userName,
            'vcenter_server': self.vcenter_host,
            'source_ip': session.ipAddress,
            'session_key': session.key
        }
        return info
        
    def display_session_info(self):
        """Display session information"""
        info = self.get_session_info()
        print("\n" + "="*70)
        print("SESSION INFORMATION")
        print("="*70)
        print(f"User            : {info['username']}")
        print(f"vCenter Server  : {info['vcenter_server']}")
        print(f"Source IP       : {info['source_ip']}")
        print(f"Session Key     : {info['session_key']}")
        print("="*70)
        
    def get_all_vms(self):
        """
        Based on: getallvms.py (lines 45-51)
        Get all VMs using CreateContainerView
        """
        container = self.content.rootFolder
        view_type = [vim.VirtualMachine]
        recursive = True
        
        container_view = self.content.viewManager.CreateContainerView(
            container, view_type, recursive
        )
        vms = container_view.view
        container_view.Destroy()
        return vms
        
    def search_vms(self, name_filter=None):
        """
        Requirement 3: Search VMs by name or return all
        Based on: getallvms.py (line 53 for regex pattern)
        """
        all_vms = self.get_all_vms()
        
        if name_filter:
            pattern = re.compile(name_filter, re.IGNORECASE)
            filtered = [vm for vm in all_vms 
                       if pattern.search(vm.summary.config.name)]
            return filtered
        else:
            return all_vms
            
    def get_vm_info(self, vm):
        """
        Requirement 4: Get VM metadata
        Based on: getallvms.py print_vm_info() (lines 27-43)
        """
        summary = vm.summary
        
        name = summary.config.name
        power_state = summary.runtime.powerState
        cpus = summary.config.numCpu
        memory_gb = summary.config.memorySizeMB / 1024.0
        
        # Get IP address
        ip_address = "N/A"
        if summary.guest is not None:
            guest_ip = summary.guest.ipAddress
            if guest_ip:
                ip_address = guest_ip
        
        info = {
            'name': name,
            'power_state': power_state,
            'cpus': cpus,
            'memory_gb': memory_gb,
            'ip_address': ip_address
        }
        return info
        
    def display_vms(self, vms):
        """Display VM information in table format"""
        if not vms:
            print("\nNo VMs found")
            return
            
        print("\n" + "="*100)
        print(f"{'VM NAME':<35} {'POWER STATE':<15} {'CPUs':<6} {'MEMORY GB':<12} {'IP ADDRESS':<25}")
        print("="*100)
        
        for vm in vms:
            info = self.get_vm_info(vm)
            print(f"{info['name']:<35} "
                  f"{info['power_state']:<15} "
                  f"{info['cpus']:<6} "
                  f"{info['memory_gb']:<12.1f} "
                  f"{info['ip_address']:<25}")
                  
        print("="*100)
        print(f"Total: {len(vms)} VMs\n")
        
    def show_menu(self):
        """Display main menu"""
        print("\n" + "="*70)
        print("VCENTER VM MANAGER")
        print("="*70)
        print("What would you like to do?")
        print("1. Show Session Info")
        print("2. List All VMs")
        print("3. Search VMs by Name")
        print("4. Exit")
        print("="*70)
        
    def run(self):
        """Main program loop"""
        if not self.load_config():
            return
            
        if not self.connect():
            return
            
        self.display_session_info()
        
        while True:
            try:
                self.show_menu()
                choice = input("Enter choice (1-4): ").strip()
                
                if choice == '1':
                    self.display_session_info()
                    
                elif choice == '2':
                    print("\nRetrieving all VMs...")
                    vms = self.search_vms()
                    self.display_vms(vms)
                    
                elif choice == '3':
                    search_term = input("Enter VM name to look for: ").strip()
                    if search_term:
                        print(f"\nLooking for '{search_term}'...")
                        vms = self.search_vms(search_term)
                        self.display_vms(vms)
                    else:
                        print("Please enter a valid search term.")
                    
                elif choice == '4':
                    print("\nDisconnecting from vCenter.")
                    break
                    
                else:
                    print("Invalid choice. Please enter 1-4.")
                    
            except vmodl.MethodFault as error:
                print(f"vSphere error: {error.msg}")
            except KeyboardInterrupt:
                print("\n\nInterrupted by user")
                break


def main():
    """Main entry point"""
    try:
        manager = VCenterManager()
        manager.run()
        return 0
    except Exception as e:
        print(f"Error: {e}")
        return -1


if __name__ == "__main__":
    main()
