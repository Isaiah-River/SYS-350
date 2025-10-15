#!/usr/bin/env python3
"""
vCenter VM Manager - Milestone 5.2
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
        # Initialization
        self.si = None
        self.content = None
        self.vcenter_host = None
        self.username = None
        
    def load_config(self):
        """Requirement 1: Read username and vcenter hostname from file"""
        # Load vcenter_config.json configuration file, and set variables
        try:
            with open('vcenter_config.json', 'r') as f:
                config = json.load(f)
                self.vcenter_host = config['vcenter_host']
                self.username = config['username']
                return True
        except FileNotFoundError:
            print("Error: vcenter_config.json not found!")
            return False
            
    def connect(self):
        """
        Based on: hello_world_vcenter.py
        Simple connection without tools module
        """
        # Get the password for the user
        password = getpass.getpass(f"Password for {self.username}: ")
        
        # Disable SSL verification for lab environment
        context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
        context.verify_mode = ssl.CERT_NONE
        
        # Attempt to connect to vCenter
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
        # Pull session information
        session = self.si.content.sessionManager.currentSession
        
        # Set dictionary for printing out in table
        info = {
            'username': session.userName,
            'vcenter_server': self.vcenter_host,
            'source_ip': session.ipAddress,
            'session_key': session.key
        }
        return info
        
    def display_session_info(self):
        """Display session information"""
        # Format a table with the pulled session information
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
        # Set the starting folder, and set search for VMs
        container = self.content.rootFolder
        view_type = [vim.VirtualMachine]
        recursive = True
        
        # Create a "view" for VMs
        container_view = self.content.viewManager.CreateContainerView(
            container, view_type, recursive
        )
        
        # Pull the VMs
        vms = container_view.view
        container_view.Destroy()
        return vms
        
    def search_vms(self, name_filter=None):
        """
        Requirement 3: Search VMs by name or return all
        Based on: getallvms.py (line 53 for regex pattern)
        """
        # Pull all VMs
        all_vms = self.get_all_vms()
        
        # Search for the provided name_filter within the collected VMs
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
        # Set variables for various VM information
        summary = vm.summary
        name = summary.config.name
        power_state = summary.runtime.powerState
        cpus = summary.config.numCpu
        memory_gb = summary.config.memorySizeMB / 1024.0
        
        # Get IP address and assign variable if IP address is found
        ip_address = "N/A"
        if summary.guest is not None:
            guest_ip = summary.guest.ipAddress
            if guest_ip:
                ip_address = guest_ip
                
        # Set dictionary for printing out in table
        info = {
            'name': name,
            'power_state': power_state,
            'cpus': cpus,
            'memory_gb': memory_gb,
            'ip_address': ip_address
        }
        return info
        
    def display_vms(self, vms):
        """
        Display VM information in table format
        Based on: Table formatting help by claude.ai
        """
        # Check if there were no VMs found
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
    
    # ========== MILESTONE 5.2 ==========
    
    def power_on_vms(self, vms):
        """
        Action 1: Power on VMs from filtered list
        Based on: vm_power_on.py (line 35)
        """
        # Check if there are VMs to work with
        if not vms:
            print("No VMs to power on")
            return
            
        print(f"\nAttempting to power on {len(vms)} VM(s)...")
        
        # Loop through each VM and power it on
        for vm in vms:
            try:
                # Check if already powered on
                if vm.runtime.powerState == "poweredOn":
                    print(f"  {vm.name} is already powered on")
                else:
                    print(f"  Powering on {vm.name}...")
                    task = vm.PowerOn()
                    self.wait_for_task(task)
                    print(f"  {vm.name} powered on successfully")
            except Exception as e:
                print(f"  Error powering on {vm.name}: {e}")
                
    def power_off_vms(self, vms):
        """
        Action 1 (continued): Power off VMs from filtered list
        Based on: destroy_vm.py (line 52)
        """
        # Check if there are VMs to work with
        if not vms:
            print("No VMs to power off")
            return
            
        print(f"\nAttempting to power off {len(vms)} VM(s)...")
        
        # Loop through each VM and power it off
        for vm in vms:
            try:
                # Check if already powered off
                if vm.runtime.powerState == "poweredOff":
                    print(f"  {vm.name} is already powered off")
                else:
                    print(f"  Powering off {vm.name}...")
                    task = vm.PowerOffVM_Task()
                    self.wait_for_task(task)
                    print(f"  {vm.name} powered off successfully")
            except Exception as e:
                print(f"  Error powering off {vm.name}: {e}")
    
    def create_snapshot(self, vms):
        """
        Action 2: Create snapshots for filtered VMs
        Based on: create_snapshot.py (lines 35-36) and snapshot_operations.py (lines 90-95)
        """
        # Check if there are VMs to work with
        if not vms:
            print("No VMs to snapshot")
            return
            
        # Get snapshot name from user
        snap_name = input("Enter snapshot name: ").strip()
        if not snap_name:
            print("Snapshot name cannot be empty")
            return
            
        snap_desc = input("Enter snapshot description (optional): ").strip()
        
        print(f"\nCreating snapshot '{snap_name}' for {len(vms)} VM(s)...")
        
        # Loop through each VM and create snapshot
        for vm in vms:
            try:
                print(f"  Creating snapshot for {vm.name}...")
                task = vm.CreateSnapshot_Task(
                    name=snap_name,
                    description=snap_desc,
                    memory=False,
                    quiesce=False
                )
                self.wait_for_task(task)
                print(f"  Snapshot created for {vm.name}")
            except Exception as e:
                print(f"  Error creating snapshot for {vm.name}: {e}")
    
    def revert_to_snapshot(self, vms):
        """
        Action 3: Revert VMs to their latest snapshot
        Based on: snapshot_operations.py (lines 113-114)
        """
        # Check if there are VMs to work with
        if not vms:
            print("No VMs to revert")
            return
            
        # Confirm with user before reverting
        confirm = input(f"Revert {len(vms)} VM(s) to latest snapshot? (yes/no): ")
        if confirm.lower() != 'yes':
            print("Operation cancelled")
            return
            
        print(f"\nReverting {len(vms)} VM(s) to latest snapshot...")
        
        # Loop through each VM and revert to snapshot
        for vm in vms:
            try:
                # Check if VM has snapshots
                if vm.snapshot is None:
                    print(f"  {vm.name} has no snapshots")
                    continue
                    
                # Get current snapshot and revert to it
                current_snap = vm.snapshot.currentSnapshot
                print(f"  Reverting {vm.name}...")
                task = current_snap.RevertToSnapshot_Task()
                self.wait_for_task(task)
                print(f"  {vm.name} reverted successfully")
            except Exception as e:
                print(f"  Error reverting {vm.name}: {e}")
    
    def change_vm_resources(self, vms):
        """
        Action 4: Change CPU and/or Memory for VMs
        Based on: change_vm_cd_backend.py (lines 74-75, ReconfigVM_Task pattern)
        """
        # Check if there are VMs to work with
        if not vms:
            print("No VMs to reconfigure")
            return
            
        # Get new resource values from user
        print("\nChange VM Resources")
        print("Leave blank to skip that resource")
        new_cpu = input("New CPU count: ").strip()
        new_memory = input("New Memory (GB): ").strip()
        
        # Check if user entered anything
        if not new_cpu and not new_memory:
            print("No changes specified")
            return
            
        print(f"\nReconfiguring {len(vms)} VM(s)...")
        
        # Loop through each VM and change resources
        for vm in vms:
            try:
                # VM must be powered off to change CPU/Memory
                if vm.runtime.powerState == "poweredOn":
                    print(f"  {vm.name} must be powered off to change resources")
                    continue
                    
                # Create configuration spec
                spec = vim.vm.ConfigSpec()
                
                if new_cpu:
                    spec.numCPUs = int(new_cpu)
                if new_memory:
                    spec.memoryMB = int(float(new_memory) * 1024)
                    
                print(f"  Reconfiguring {vm.name}...")
                task = vm.ReconfigVM_Task(spec=spec)
                self.wait_for_task(task)
                print(f"  {vm.name} reconfigured successfully")
            except Exception as e:
                print(f"  Error reconfiguring {vm.name}: {e}")
    
    def change_vm_network(self, vms):
        """
        Action 5: Change the network for VMs
        Based on: add_nic_to_vm.py (lines 51-55) and change_vm_nic_state.py (lines 49-51, 65)
        """
        # Check if there are VMs to work with
        if not vms:
            print("No VMs to change network")
            return
            
        # Get network name from user
        network_name = input("Enter new network/portgroup name: ").strip()
        if not network_name:
            print("Network name cannot be empty")
            return
            
        # Find the network
        network = self.get_network(network_name)
        if not network:
            print(f"Network '{network_name}' not found")
            return
            
        print(f"\nChanging network to '{network_name}' for {len(vms)} VM(s)...")
        
        # Loop through each VM and change network
        for vm in vms:
            try:
                # Find first network adapter
                nic_device = None
                for dev in vm.config.hardware.device:
                    if isinstance(dev, vim.vm.device.VirtualEthernetCard):
                        nic_device = dev
                        break
                        
                if not nic_device:
                    print(f"  {vm.name} has no network adapter")
                    continue
                    
                # Create spec to change network
                nic_spec = vim.vm.device.VirtualDeviceSpec()
                nic_spec.operation = vim.vm.device.VirtualDeviceSpec.Operation.edit
                nic_spec.device = nic_device
                nic_spec.device.backing = vim.vm.device.VirtualEthernetCard.NetworkBackingInfo()
                nic_spec.device.backing.deviceName = network_name
                
                spec = vim.vm.ConfigSpec()
                spec.deviceChange = [nic_spec]
                
                print(f"  Changing network for {vm.name}...")
                task = vm.ReconfigVM_Task(spec=spec)
                self.wait_for_task(task)
                print(f"  {vm.name} network changed successfully")
            except Exception as e:
                print(f"  Error changing network for {vm.name}: {e}")
    
    def delete_vms(self, vms):
        """
        Action 6: Delete VMs from disk
        Based on: destroy_vm.py (lines 52-59)
        """
        # Check if there are VMs to work with
        if not vms:
            print("No VMs to delete")
            return
            
        # Show warning and get confirmation
        print("\n" + "="*70)
        print("WARNING: This will PERMANENTLY DELETE the following VMs:")
        for vm in vms:
            print(f"  - {vm.name}")
        print("="*70)
        
        confirm = input("Type 'DELETE' to confirm: ").strip()
        if confirm != 'DELETE':
            print("Operation cancelled")
            return
            
        print(f"\nDeleting {len(vms)} VM(s)...")
        
        # Loop through each VM and delete it
        for vm in vms:
            try:
                # Power off if needed
                if vm.runtime.powerState == "poweredOn":
                    print(f"  Powering off {vm.name}...")
                    task = vm.PowerOffVM_Task()
                    self.wait_for_task(task)
                    
                # Delete VM
                print(f"  Deleting {vm.name}...")
                task = vm.Destroy_Task()
                self.wait_for_task(task)
                print(f"  {vm.name} deleted successfully")
            except Exception as e:
                print(f"  Error deleting {vm.name}: {e}")
    
    # ========== HELPER METHODS ==========
    
    def wait_for_task(self, task):
        """
        Wait for a vCenter task to complete
        Based on: snapshot_operations.py (WaitForTask pattern)
        """
        # Wait until task is done
        while task.info.state not in ['success', 'error']:
            pass
            
        # Raise error if task failed
        if task.info.state == 'error':
            raise Exception(task.info.error.msg)
    
    def get_network(self, network_name):
        """
        Find a network by name
        Based on: getallvms.py CreateContainerView pattern (lines 45-51)
        """
        # Search for networks using CreateContainerView
        container = self.content.rootFolder
        view_type = [vim.Network]
        recursive = True
        
        container_view = self.content.viewManager.CreateContainerView(
            container, view_type, recursive
        )
        networks = container_view.view
        container_view.Destroy()
        
        # Find matching network
        for network in networks:
            if network.name == network_name:
                return network
        return None
    
    # ========== MENU METHODS ==========
    
    def show_main_menu(self):
        """
        Display main menu
        Based on: My Advanced Python final's show_menu() function, with table formatting help by claude.ai
        """
        print("\n" + "="*70)
        print("VCENTER VM MANAGER - Milestone 5.2")
        print("="*70)
        print("What would you like to do?")
        print("1. Show Session Info")
        print("2. List All VMs")
        print("3. Search and Perform Actions")
        print("4. Exit")
        print("="*70)
    
    def show_actions_menu(self):
        """Display actions menu"""
        print("\n" + "="*70)
        print("VM ACTIONS MENU")
        print("="*70)
        print("1. Power On VMs")
        print("2. Power Off VMs")
        print("3. Create Snapshot")
        print("4. Revert to Latest Snapshot")
        print("5. Change CPU/Memory")
        print("6. Change Network")
        print("7. Delete VMs")
        print("8. Back to Main Menu")
        print("="*70)
        
    def actions_submenu(self, vms):
        """Actions submenu for filtered VMs"""
        while True:
            self.show_actions_menu()
            choice = input("Enter choice (1-8): ").strip()
            
            if choice == '1':
                self.power_on_vms(vms)
            elif choice == '2':
                self.power_off_vms(vms)
            elif choice == '3':
                self.create_snapshot(vms)
            elif choice == '4':
                self.revert_to_snapshot(vms)
            elif choice == '5':
                self.change_vm_resources(vms)
            elif choice == '6':
                self.change_vm_network(vms)
            elif choice == '7':
                self.delete_vms(vms)
            elif choice == '8':
                break
            else:
                print("Invalid choice. Please enter 1-8.")
        
    def run(self):
        """Main program loop"""
        # Load config and connect
        if not self.load_config():
            return
            
        if not self.connect():
            return
            
        self.display_session_info()
        
        # Main menu loop
        while True:
            try:
                self.show_main_menu()
                choice = input("Enter choice (1-4): ").strip()
                
                if choice == '1':
                    self.display_session_info()
                    
                elif choice == '2':
                    print("\nRetrieving all VMs...")
                    vms = self.search_vms()
                    self.display_vms(vms)
                    
                elif choice == '3':
                    # Get filter from user
                    search_term = input("Enter VM name to filter (or press Enter for all): ").strip()
                    if search_term:
                        print(f"\nLooking for '{search_term}'...")
                        vms = self.search_vms(search_term)
                    else:
                        print("\nRetrieving all VMs...")
                        vms = self.search_vms()
                        
                    # Display VMs
                    self.display_vms(vms)
                    
                    # Go to actions menu if VMs found
                    if vms:
                        self.actions_submenu(vms)
                    
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

#!/usr/bin/env python3
"""
vCenter VM Manager - Milestone 5.2
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
        # Initialization
        self.si = None
        self.content = None
        self.vcenter_host = None
        self.username = None
        
    def load_config(self):
        """Requirement 1: Read username and vcenter hostname from file"""
        # Load vcenter_config.json configuration file, and set variables
        try:
            with open('vcenter_config.json', 'r') as f:
                config = json.load(f)
                self.vcenter_host = config['vcenter_host']
                self.username = config['username']
                return True
        except FileNotFoundError:
            print("Error: vcenter_config.json not found!")
            return False
            
    def connect(self):
        """
        Based on: hello_world_vcenter.py
        Simple connection without tools module
        """
        # Get the password for the user
        password = getpass.getpass(f"Password for {self.username}: ")
        
        # Disable SSL verification for lab environment
        context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
        context.verify_mode = ssl.CERT_NONE
        
        # Attempt to connect to vCenter
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
        # Pull session information
        session = self.si.content.sessionManager.currentSession
        
        # Set dictionary for printing out in table
        info = {
            'username': session.userName,
            'vcenter_server': self.vcenter_host,
            'source_ip': session.ipAddress,
            'session_key': session.key
        }
        return info
        
    def display_session_info(self):
        """Display session information"""
        # Format a table with the pulled session information
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
        # Set the starting folder, and set search for VMs
        container = self.content.rootFolder
        view_type = [vim.VirtualMachine]
        recursive = True
        
        # Create a "view" for VMs
        container_view = self.content.viewManager.CreateContainerView(
            container, view_type, recursive
        )
        
        # Pull the VMs
        vms = container_view.view
        container_view.Destroy()
        return vms
        
    def search_vms(self, name_filter=None):
        """
        Requirement 3: Search VMs by name or return all
        Based on: getallvms.py (line 53 for regex pattern)
        """
        # Pull all VMs
        all_vms = self.get_all_vms()
        
        # Search for the provided name_filter within the collected VMs
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
        # Set variables for various VM information
        summary = vm.summary
        name = summary.config.name
        power_state = summary.runtime.powerState
        cpus = summary.config.numCpu
        memory_gb = summary.config.memorySizeMB / 1024.0
        
        # Get IP address and assign variable if IP address is found
        ip_address = "N/A"
        if summary.guest is not None:
            guest_ip = summary.guest.ipAddress
            if guest_ip:
                ip_address = guest_ip
                
        # Set dictionary for printing out in table
        info = {
            'name': name,
            'power_state': power_state,
            'cpus': cpus,
            'memory_gb': memory_gb,
            'ip_address': ip_address
        }
        return info
        
    def display_vms(self, vms):
        """
        Display VM information in table format
        Based on: Table formatting help by claude.ai
        """
        # Check if there were no VMs found
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
    
    # ========== MILESTONE 5.2 ==========
    
    def power_on_vms(self, vms):
        """
        Action 1: Power on VMs from filtered list
        Based on: vm_power_on.py (line 35)
        """
        # Check if there are VMs to work with
        if not vms:
            print("No VMs to power on")
            return
            
        print(f"\nAttempting to power on {len(vms)} VM(s)...")
        
        # Loop through each VM and power it on
        for vm in vms:
            try:
                # Check if already powered on
                if vm.runtime.powerState == "poweredOn":
                    print(f"  {vm.name} is already powered on")
                else:
                    print(f"  Powering on {vm.name}...")
                    task = vm.PowerOn()
                    self.wait_for_task(task)
                    print(f"  {vm.name} powered on successfully")
            except Exception as e:
                print(f"  Error powering on {vm.name}: {e}")
                
    def power_off_vms(self, vms):
        """
        Action 1 (continued): Power off VMs from filtered list
        Based on: destroy_vm.py (line 52)
        """
        # Check if there are VMs to work with
        if not vms:
            print("No VMs to power off")
            return
            
        print(f"\nAttempting to power off {len(vms)} VM(s)...")
        
        # Loop through each VM and power it off
        for vm in vms:
            try:
                # Check if already powered off
                if vm.runtime.powerState == "poweredOff":
                    print(f"  {vm.name} is already powered off")
                else:
                    print(f"  Powering off {vm.name}...")
                    task = vm.PowerOffVM_Task()
                    self.wait_for_task(task)
                    print(f"  {vm.name} powered off successfully")
            except Exception as e:
                print(f"  Error powering off {vm.name}: {e}")
    
    def create_snapshot(self, vms):
        """
        Action 2: Create snapshots for filtered VMs
        Based on: create_snapshot.py (lines 35-36) and snapshot_operations.py (lines 90-95)
        """
        # Check if there are VMs to work with
        if not vms:
            print("No VMs to snapshot")
            return
            
        # Get snapshot name from user
        snap_name = input("Enter snapshot name: ").strip()
        if not snap_name:
            print("Snapshot name cannot be empty")
            return
            
        snap_desc = input("Enter snapshot description (optional): ").strip()
        
        print(f"\nCreating snapshot '{snap_name}' for {len(vms)} VM(s)...")
        
        # Loop through each VM and create snapshot
        for vm in vms:
            try:
                print(f"  Creating snapshot for {vm.name}...")
                task = vm.CreateSnapshot_Task(
                    name=snap_name,
                    description=snap_desc,
                    memory=False,
                    quiesce=False
                )
                self.wait_for_task(task)
                print(f"  Snapshot created for {vm.name}")
            except Exception as e:
                print(f"  Error creating snapshot for {vm.name}: {e}")
    
    def revert_to_snapshot(self, vms):
        """
        Action 3: Revert VMs to their latest snapshot
        Based on: snapshot_operations.py (lines 113-114)
        """
        # Check if there are VMs to work with
        if not vms:
            print("No VMs to revert")
            return
            
        # Confirm with user before reverting
        confirm = input(f"Revert {len(vms)} VM(s) to latest snapshot? (yes/no): ")
        if confirm.lower() != 'yes':
            print("Operation cancelled")
            return
            
        print(f"\nReverting {len(vms)} VM(s) to latest snapshot...")
        
        # Loop through each VM and revert to snapshot
        for vm in vms:
            try:
                # Check if VM has snapshots
                if vm.snapshot is None:
                    print(f"  {vm.name} has no snapshots")
                    continue
                    
                # Get current snapshot and revert to it
                current_snap = vm.snapshot.currentSnapshot
                print(f"  Reverting {vm.name}...")
                task = current_snap.RevertToSnapshot_Task()
                self.wait_for_task(task)
                print(f"  {vm.name} reverted successfully")
            except Exception as e:
                print(f"  Error reverting {vm.name}: {e}")
    
    def change_vm_resources(self, vms):
        """
        Action 4: Change CPU and/or Memory for VMs
        Based on: change_vm_cd_backend.py (lines 74-75, ReconfigVM_Task pattern)
        """
        # Check if there are VMs to work with
        if not vms:
            print("No VMs to reconfigure")
            return
            
        # Get new resource values from user
        print("\nChange VM Resources")
        print("Leave blank to skip that resource")
        new_cpu = input("New CPU count: ").strip()
        new_memory = input("New Memory (GB): ").strip()
        
        # Check if user entered anything
        if not new_cpu and not new_memory:
            print("No changes specified")
            return
            
        print(f"\nReconfiguring {len(vms)} VM(s)...")
        
        # Loop through each VM and change resources
        for vm in vms:
            try:
                # VM must be powered off to change CPU/Memory
                if vm.runtime.powerState == "poweredOn":
                    print(f"  {vm.name} must be powered off to change resources")
                    continue
                    
                # Create configuration spec
                spec = vim.vm.ConfigSpec()
                
                if new_cpu:
                    spec.numCPUs = int(new_cpu)
                if new_memory:
                    spec.memoryMB = int(float(new_memory) * 1024)
                    
                print(f"  Reconfiguring {vm.name}...")
                task = vm.ReconfigVM_Task(spec=spec)
                self.wait_for_task(task)
                print(f"  {vm.name} reconfigured successfully")
            except Exception as e:
                print(f"  Error reconfiguring {vm.name}: {e}")
    
    def change_vm_network(self, vms):
        """
        Action 5: Change the network for VMs
        Based on: add_nic_to_vm.py (lines 51-55) and change_vm_nic_state.py (lines 49-51, 65)
        """
        # Check if there are VMs to work with
        if not vms:
            print("No VMs to change network")
            return
            
        # Get network name from user
        network_name = input("Enter new network/portgroup name: ").strip()
        if not network_name:
            print("Network name cannot be empty")
            return
            
        # Find the network
        network = self.get_network(network_name)
        if not network:
            print(f"Network '{network_name}' not found")
            return
            
        print(f"\nChanging network to '{network_name}' for {len(vms)} VM(s)...")
        
        # Loop through each VM and change network
        for vm in vms:
            try:
                # Find first network adapter
                nic_device = None
                for dev in vm.config.hardware.device:
                    if isinstance(dev, vim.vm.device.VirtualEthernetCard):
                        nic_device = dev
                        break
                        
                if not nic_device:
                    print(f"  {vm.name} has no network adapter")
                    continue
                    
                # Create spec to change network
                nic_spec = vim.vm.device.VirtualDeviceSpec()
                nic_spec.operation = vim.vm.device.VirtualDeviceSpec.Operation.edit
                nic_spec.device = nic_device
                nic_spec.device.backing = vim.vm.device.VirtualEthernetCard.NetworkBackingInfo()
                nic_spec.device.backing.deviceName = network_name
                
                spec = vim.vm.ConfigSpec()
                spec.deviceChange = [nic_spec]
                
                print(f"  Changing network for {vm.name}...")
                task = vm.ReconfigVM_Task(spec=spec)
                self.wait_for_task(task)
                print(f"  {vm.name} network changed successfully")
            except Exception as e:
                print(f"  Error changing network for {vm.name}: {e}")
    
    def delete_vms(self, vms):
        """
        Action 6: Delete VMs from disk
        Based on: destroy_vm.py (lines 52-59)
        """
        # Check if there are VMs to work with
        if not vms:
            print("No VMs to delete")
            return
            
        # Show warning and get confirmation
        print("\n" + "="*70)
        print("WARNING: This will PERMANENTLY DELETE the following VMs:")
        for vm in vms:
            print(f"  - {vm.name}")
        print("="*70)
        
        confirm = input("Type 'DELETE' to confirm: ").strip()
        if confirm != 'DELETE':
            print("Operation cancelled")
            return
            
        print(f"\nDeleting {len(vms)} VM(s)...")
        
        # Loop through each VM and delete it
        for vm in vms:
            try:
                # Power off if needed
                if vm.runtime.powerState == "poweredOn":
                    print(f"  Powering off {vm.name}...")
                    task = vm.PowerOffVM_Task()
                    self.wait_for_task(task)
                    
                # Delete VM
                print(f"  Deleting {vm.name}...")
                task = vm.Destroy_Task()
                self.wait_for_task(task)
                print(f"  {vm.name} deleted successfully")
            except Exception as e:
                print(f"  Error deleting {vm.name}: {e}")
    
    # ========== HELPER METHODS ==========
    
    def wait_for_task(self, task):
        """
        Wait for a vCenter task to complete
        Based on: snapshot_operations.py (WaitForTask pattern)
        """
        # Wait until task is done
        while task.info.state not in ['success', 'error']:
            pass
            
        # Raise error if task failed
        if task.info.state == 'error':
            raise Exception(task.info.error.msg)
    
    def get_network(self, network_name):
        """
        Find a network by name
        Based on: getallvms.py CreateContainerView pattern (lines 45-51)
        """
        # Search for networks using CreateContainerView
        container = self.content.rootFolder
        view_type = [vim.Network]
        recursive = True
        
        container_view = self.content.viewManager.CreateContainerView(
            container, view_type, recursive
        )
        networks = container_view.view
        container_view.Destroy()
        
        # Find matching network
        for network in networks:
            if network.name == network_name:
                return network
        return None
    
    # ========== MENU METHODS ==========
    
    def show_main_menu(self):
        """
        Display main menu
        Based on: My Advanced Python final's show_menu() function, with table formatting help by claude.ai
        """
        print("\n" + "="*70)
        print("VCENTER VM MANAGER - Milestone 5.2")
        print("="*70)
        print("What would you like to do?")
        print("1. Show Session Info")
        print("2. List All VMs")
        print("3. Search and Perform Actions")
        print("4. Exit")
        print("="*70)
    
    def show_actions_menu(self):
        """Display actions menu"""
        print("\n" + "="*70)
        print("VM ACTIONS MENU")
        print("="*70)
        print("1. Power On VMs")
        print("2. Power Off VMs")
        print("3. Create Snapshot")
        print("4. Revert to Latest Snapshot")
        print("5. Change CPU/Memory")
        print("6. Change Network")
        print("7. Delete VMs")
        print("8. Back to Main Menu")
        print("="*70)
        
    def actions_submenu(self, vms):
        """Actions submenu for filtered VMs"""
        while True:
            self.show_actions_menu()
            choice = input("Enter choice (1-8): ").strip()
            
            if choice == '1':
                self.power_on_vms(vms)
            elif choice == '2':
                self.power_off_vms(vms)
            elif choice == '3':
                self.create_snapshot(vms)
            elif choice == '4':
                self.revert_to_snapshot(vms)
            elif choice == '5':
                self.change_vm_resources(vms)
            elif choice == '6':
                self.change_vm_network(vms)
            elif choice == '7':
                self.delete_vms(vms)
            elif choice == '8':
                break
            else:
                print("Invalid choice. Please enter 1-8.")
        
    def run(self):
        """Main program loop"""
        # Load config and connect
        if not self.load_config():
            return
            
        if not self.connect():
            return
            
        self.display_session_info()
        
        # Main menu loop
        while True:
            try:
                self.show_main_menu()
                choice = input("Enter choice (1-4): ").strip()
                
                if choice == '1':
                    self.display_session_info()
                    
                elif choice == '2':
                    print("\nRetrieving all VMs...")
                    vms = self.search_vms()
                    self.display_vms(vms)
                    
                elif choice == '3':
                    # Get filter from user
                    search_term = input("Enter VM name to filter (or press Enter for all): ").strip()
                    if search_term:
                        print(f"\nLooking for '{search_term}'...")
                        vms = self.search_vms(search_term)
                    else:
                        print("\nRetrieving all VMs...")
                        vms = self.search_vms()
                        
                    # Display VMs
                    self.display_vms(vms)
                    
                    # Go to actions menu if VMs found
                    if vms:
                        self.actions_submenu(vms)
                    
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
