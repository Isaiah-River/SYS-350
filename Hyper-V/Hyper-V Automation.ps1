function Get-VMSummary {
    param([string]$VMName = "*")
   
    $vms = Get-VM -Name $VMName
   
    $results = @()
    foreach ($vm in $vms) {
        $ips = "N/A"
        $adapters = Get-VMNetworkAdapter -VM $vm -ErrorAction SilentlyContinue
        if ($adapters -and $adapters[0].IPAddresses) {
            $ips = $adapters[0].IPAddresses[0]
        }
       
        $results += [PSCustomObject]@{
            Name = $vm.Name
            State = $vm.State
            IPAddress = $ips
            CPUs = $vm.ProcessorCount
            MemoryMB = [math]::Round($vm.MemoryAssigned / 1MB)
        }
    }
   
    return $results | Format-Table -AutoSize
}


function Get-VMDetails {
    param([Parameter(Mandatory=$true)][string]$VMName)
   
    $vm = Get-VM -Name $VMName
   
    Write-Host "`n=== VM Details: $VMName ===" -ForegroundColor Cyan
   
    Write-Host "`nBasic Info:" -ForegroundColor Yellow
    Write-Host "  Name: $($vm.Name)"
    Write-Host "  State: $($vm.State)"
    Write-Host "  Generation: $($vm.Generation)"
    Write-Host "  Path: $($vm.Path)"
   
    Write-Host "`nResources:" -ForegroundColor Yellow
    Write-Host "  CPUs: $($vm.ProcessorCount)"
    Write-Host "  Memory: $([math]::Round($vm.MemoryStartup / 1GB, 2)) GB"
   
    Write-Host "`nNetwork:" -ForegroundColor Yellow
    $adapters = Get-VMNetworkAdapter -VM $vm
    foreach ($adapter in $adapters) {
        Write-Host "  Switch: $($adapter.SwitchName)"
        Write-Host "  MAC: $($adapter.MacAddress)"
        if ($adapter.IPAddresses) {
            Write-Host "  IP: $($adapter.IPAddresses -join ', ')"
        }
    }
   
    Write-Host "`nDisks:" -ForegroundColor Yellow
    $disks = Get-VMHardDiskDrive -VM $vm
    foreach ($disk in $disks) {
        if ($disk.Path) {
            $vhd = Get-VHD -Path $disk.Path -ErrorAction SilentlyContinue
            if ($vhd) {
                Write-Host "  Path: $($disk.Path)"
                Write-Host "  Type: $($vhd.VhdType)"
                Write-Host "  Size: $([math]::Round($vhd.FileSize / 1GB, 2)) GB"
            }
        }
    }
   
    Write-Host "`nCheckpoints:" -ForegroundColor Yellow
    $checkpoints = Get-VMSnapshot -VM $vm -ErrorAction SilentlyContinue
    if ($checkpoints) {
        foreach ($cp in $checkpoints) {
            Write-Host "  $($cp.Name) - $($cp.CreationTime)"
        }
    } else {
        Write-Host "  None"
    }
   
    Write-Host ""
}


function Restore-LatestCheckpoint {
    param([Parameter(Mandatory=$true)][string]$VMName)
   
    $vm = Get-VM -Name $VMName
    $checkpoints = Get-VMSnapshot -VM $vm | Sort-Object CreationTime -Descending
   
    if (-not $checkpoints) {
        Write-Host "No checkpoints found for $VMName" -ForegroundColor Yellow
        return
    }
   
    $latest = $checkpoints[0]
    Write-Host "Restoring checkpoint: $($latest.Name)" -ForegroundColor Cyan
    Write-Host "Created: $($latest.CreationTime)" -ForegroundColor Gray
   
    $confirm = Read-Host "Continue? (Y/N)"
    if ($confirm -eq 'Y') {
        Restore-VMSnapshot -VMSnapshot $latest -Confirm:$false
        Write-Host "Checkpoint restored!" -ForegroundColor Green
    }
}


function New-VMFullClone {
    param(
        [Parameter(Mandatory=$true)][string]$SourceVMName,
        [Parameter(Mandatory=$true)][string]$NewVMName,
        [Parameter(Mandatory=$true)][string]$DestinationPath
    )
   
    try {
        # Get source VM
        $sourceVM = Get-VM -Name $SourceVMName -ErrorAction Stop
       
        Write-Host "`nChecking VM state..." -ForegroundColor Cyan
       
        # Ensure VM is completely off
        if ($sourceVM.State -ne 'Off') {
            Write-Host "VM must be powered off. Stopping now..." -ForegroundColor Yellow
            Stop-VM -Name $SourceVMName -Force -TurnOff
            Start-Sleep -Seconds 5
            $sourceVM = Get-VM -Name $SourceVMName
        }
       
        Write-Host "VM is off. Proceeding with clone..." -ForegroundColor Green
       
        # Create destination directory
        if (-not (Test-Path $DestinationPath)) {
            Write-Host "Creating directory: $DestinationPath" -ForegroundColor Cyan
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        }
       
        # Get source VM disk
        $sourceDisks = Get-VMHardDiskDrive -VMName $SourceVMName
        if (-not $sourceDisks) {
            Write-Host "ERROR: No disks found on source VM" -ForegroundColor Red
            return
        }
       
        $sourceDisk = $sourceDisks[0].Path
        Write-Host "Source disk: $sourceDisk" -ForegroundColor Gray
       
        # Create new VHD by copying
        $newDiskName = "$NewVMName.vhdx"
        $newDiskPath = Join-Path $DestinationPath $newDiskName
       
        Write-Host "Copying disk (this may take a while)..." -ForegroundColor Cyan
        Copy-Item -Path $sourceDisk -Destination $newDiskPath -Force
       
        Write-Host "Creating new VM..." -ForegroundColor Cyan
       
        # Create new VM with copied disk
        $newVM = New-VM -Name $NewVMName `
                        -MemoryStartupBytes $sourceVM.MemoryStartup `
                        -Generation $sourceVM.Generation `
                        -VHDPath $newDiskPath `
                        -SwitchName (Get-VMNetworkAdapter -VMName $SourceVMName)[0].SwitchName
       
        # Match CPU count
        Set-VMProcessor -VMName $NewVMName -Count $sourceVM.ProcessorCount
       
        # Disable secure boot if Generation 2
        if ($sourceVM.Generation -eq 2) {
            Set-VMFirmware -VMName $NewVMName -EnableSecureBoot Off
        }
       
        Write-Host "`nClone created successfully!" -ForegroundColor Green
        Write-Host "  Name: $NewVMName" -ForegroundColor Cyan
        Write-Host "  Disk: $newDiskPath" -ForegroundColor Cyan
        Write-Host "  CPUs: $($newVM.ProcessorCount)" -ForegroundColor Cyan
        Write-Host "  Memory: $([math]::Round($newVM.MemoryStartup/1GB,2)) GB" -ForegroundColor Cyan
       
    } catch {
        Write-Host "`nERROR during clone operation:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        Write-Host "`nTroubleshooting tips:" -ForegroundColor Cyan
        Write-Host "  1. Make sure source VM is completely powered off" -ForegroundColor Gray
        Write-Host "  2. Check you have enough disk space" -ForegroundColor Gray
        Write-Host "  3. Verify you have write permissions to destination" -ForegroundColor Gray
        Write-Host "  4. Try a different destination path" -ForegroundColor Gray
    }
}


function Set-VMResources {
    param(
        [Parameter(Mandatory=$true)][string]$VMName,
        [int]$CPUCount,
        [int]$MemoryGB
    )
   
    $vm = Get-VM -Name $VMName
   
    if ($vm.State -ne 'Off') {
        Write-Host "Stopping VM..." -ForegroundColor Yellow
        Stop-VM -Name $VMName -Force
        Start-Sleep -Seconds 2
    }
   
    Write-Host "Current: $($vm.ProcessorCount) CPUs, $([math]::Round($vm.MemoryStartup/1GB,2)) GB" -ForegroundColor Gray
   
    if ($CPUCount) {
        Set-VMProcessor -VMName $VMName -Count $CPUCount
        Write-Host "CPUs changed to: $CPUCount" -ForegroundColor Green
    }
   
    if ($MemoryGB) {
        Set-VMMemory -VMName $VMName -StartupBytes ($MemoryGB * 1GB)
        Write-Host "Memory changed to: $MemoryGB GB" -ForegroundColor Green
    }
}


function Remove-VMComplete {
    param([Parameter(Mandatory=$true)][string]$VMName)
   
    $vm = Get-VM -Name $VMName
   
    Write-Host "`nWARNING: About to delete VM: $VMName" -ForegroundColor Red
    $confirm = Read-Host "Type DELETE to confirm"
   
    if ($confirm -ne 'DELETE') {
        Write-Host "Cancelled" -ForegroundColor Gray
        return
    }
   
    if ($vm.State -ne 'Off') {
        Stop-VM -Name $VMName -Force -TurnOff
    }
   
    $disks = Get-VMHardDiskDrive -VM $vm | Select-Object -ExpandProperty Path
   
    Remove-VM -Name $VMName -Force
    Write-Host "VM removed" -ForegroundColor Yellow
   
    foreach ($disk in $disks) {
        if (Test-Path $disk) {
            Remove-Item -Path $disk -Force
            Write-Host "Deleted: $disk" -ForegroundColor Gray
        }
    }
   
    Write-Host "Complete!" -ForegroundColor Green
}


function Set-VMIso {
    param(
        [Parameter(Mandatory=$true)][string]$VMName,
        [ValidateSet("Attach","Detach","Replace")]
        [string]$Action = "Attach",
        [string]$ISOPath = $null,
        [switch]$Force
    )


    try {
        # Validate VM
        $vm = Get-VM -Name $VMName -ErrorAction Stop


        # If attaching or replacing, ensure ISO file exists on host
        if ($Action -ne 'Detach') {
            if ([string]::IsNullOrWhiteSpace($ISOPath)) {
                Write-Host "No ISO path supplied for Attach/Replace action." -ForegroundColor Red
                return
            }
            if (-not (Test-Path -Path $ISOPath)) {
                Write-Host "ISO file not found: $ISOPath" -ForegroundColor Red
                return
            }
        }


        # Get existing DVD drives for the VM
        $dvdDrives = Get-VMDvdDrive -VMName $VMName -ErrorAction SilentlyContinue


        # If VM is running, warn the user (some guests may not support hot-plug)
        if ($vm.State -eq 'Running' -and -not $Force) {
            $resp = Read-Host "VM is Running. Hot-plugging may not be supported by guest. Continue? (Y/N)"
            if ($resp -ne 'Y') {
                Write-Host "Aborting operation." -ForegroundColor Yellow
                return
            }
        }


        switch ($Action) {
            'Attach' {
                if ($dvdDrives -and $dvdDrives.Count -gt 0) {
                    # Use the first existing DVD drive
                    Write-Host "Mounting ISO to existing DVD drive on VM: $VMName" -ForegroundColor Cyan
                    Set-VMDvdDrive -VMDvdDrive $dvdDrives[0] -Path $ISOPath -ErrorAction Stop
                } else {
                    # Add a new DVD drive (let Hyper-V choose controller/location) and attach
                    Write-Host "No DVD drive found. Adding DVD drive and attaching ISO to VM: $VMName" -ForegroundColor Cyan
                    try {
                        Add-VMDvdDrive -VMName $VMName -ErrorAction Stop | Out-Null
                    } catch {
                        # As a fallback, try with a common controller combo (older hosts)
                        Write-Host "Add-VMDvdDrive without parameters failed; trying fallback controller parameters..." -ForegroundColor Yellow
                        Add-VMDvdDrive -VMName $VMName -ControllerNumber 1 -ControllerLocation 0 -ErrorAction Stop | Out-Null
                    }
                    Start-Sleep -Milliseconds 300
                    # Refresh drives and set path
                    $dvdDrives = Get-VMDvdDrive -VMName $VMName -ErrorAction Stop
                    Set-VMDvdDrive -VMDvdDrive $dvdDrives[0] -Path $ISOPath -ErrorAction Stop
                }
                Write-Host "ISO attached: $ISOPath" -ForegroundColor Green
            }


            'Replace' {
                if (-not $dvdDrives -or $dvdDrives.Count -eq 0) {
                    Write-Host "No DVD drive present. Adding and attaching ISO..." -ForegroundColor Cyan
                    try {
                        Add-VMDvdDrive -VMName $VMName -ErrorAction Stop | Out-Null
                    } catch {
                        Write-Host "Fallback add attempt..." -ForegroundColor Yellow
                        Add-VMDvdDrive -VMName $VMName -ControllerNumber 1 -ControllerLocation 0 -ErrorAction Stop | Out-Null
                    }
                    Start-Sleep -Milliseconds 300
                    $dvdDrives = Get-VMDvdDrive -VMName $VMName -ErrorAction Stop
                } else {
                    Write-Host "Replacing ISO on existing DVD drive..." -ForegroundColor Cyan
                }


                Set-VMDvdDrive -VMDvdDrive $dvdDrives[0] -Path $ISOPath -ErrorAction Stop
                Write-Host "ISO replaced with: $ISOPath" -ForegroundColor Green
            }


            'Detach' {
                if (-not $dvdDrives -or $dvdDrives.Count -eq 0) {
                    Write-Host "No DVD drive present on VM: $VMName. Nothing to detach." -ForegroundColor Yellow
                    return
                }


                # Clear the path (unmount) for each drive that has a path
                $mountedPaths = $dvdDrives | Where-Object { $_.Path -and $_.Path -ne "" }
                if ($mountedPaths) {
                    foreach ($d in $mountedPaths) {
                        Write-Host "Detaching ISO from drive (Controller $($d.ControllerNumber) Location $($d.ControllerLocation)): $($d.Path)" -ForegroundColor Cyan
                        Set-VMDvdDrive -VMDvdDrive $d -Path $null -ErrorAction Stop
                    }
                    Write-Host "ISO(s) detached." -ForegroundColor Green
                } else {
                    Write-Host "No ISO mounted to detach. Optionally removing DVD drive(s)..." -ForegroundColor Gray
                }


                # Ask whether to remove the virtual DVD drive altogether
                $removeDrive = Read-Host "Remove the virtual DVD drive(s) entirely? (Y/N)"
                if ($removeDrive -eq 'Y') {
                    # Remove by piping the drive objects to Remove-VMDvdDrive
                    $dvdDrives | ForEach-Object {
                        try {
                            $_ | Remove-VMDvdDrive -Confirm:$false -ErrorAction Stop
                        } catch {
                            Write-Host "Failed to remove DVD drive Controller $($_.ControllerNumber) Location $($_.ControllerLocation): $($_.Exception.Message)" -ForegroundColor Yellow
                        }
                    }
                    Write-Host "DVD drive(s) removed." -ForegroundColor Green
                }
            }
        }


    } catch {
        Write-Host "ERROR (Set-VMIso) for VM '$VMName':" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }
}






function Toggle-VMSecureBoot {
    param(
        [Parameter(Mandatory=$true)][string]$VMName,
        [ValidateSet("Enable","Disable","Toggle")]
        [string]$Action = "Toggle",
        [switch]$ForceStop
    )


    try {
        $vm = Get-VM -Name $VMName -ErrorAction Stop


        # Only Gen 2 supports Secure Boot
        if ($vm.Generation -ne 2) {
            Write-Host "Secure Boot is only supported on Generation 2 VMs. '$VMName' is Generation $($vm.Generation)." -ForegroundColor Yellow
            return
        }


        # Get firmware info
        $firmware = Get-VMFirmware -VMName $VMName -ErrorAction Stop


        # Normalize current state to a boolean ($true = enabled, $false = disabled)
        $currentState = $false
        if ($firmware.PSObject.Properties.Name -contains "EnableSecureBoot") {
            $val = $firmware.EnableSecureBoot
        } elseif ($firmware.PSObject.Properties.Name -contains "SecureBoot") {
            $val = $firmware.SecureBoot
        } else {
            $val = $null
        }


        if ($null -ne $val) {
            # If it's the OnOffState enum (common), convert to boolean by checking for 'On'
            if ($val -is [Microsoft.HyperV.PowerShell.OnOffState]) {
                $currentState = ($val -eq [Microsoft.HyperV.PowerShell.OnOffState]::On)
            } else {
                # Try boolean cast as a fallback
                $currentState = [bool]$val
            }
        }


        Write-Host "VM: $VMName  |  Current Secure Boot: $currentState" -ForegroundColor Cyan


        # If VM is running, ask to stop unless ForceStop specified
        if ($vm.State -eq 'Running' -and -not $ForceStop) {
            $stopChoice = Read-Host "VM is running and Secure Boot changes require the VM to be Off. Stop VM now? (Y/N)"
            if ($stopChoice -ne 'Y') {
                Write-Host "Aborting - VM must be Off to change Secure Boot." -ForegroundColor Yellow
                return
            } else {
                Write-Host "Stopping VM: $VMName ..." -ForegroundColor Cyan
                Stop-VM -Name $VMName -Force -TurnOff
                # Wait for it to go off (timeout after 60s)
                $waitStart = Get-Date
                while ((Get-VM -Name $VMName).State -ne 'Off') {
                    Start-Sleep -Seconds 1
                    if ((Get-Date) - $waitStart -gt (New-TimeSpan -Seconds 60)) {
                        Write-Host "Timed out waiting for VM to stop. Aborting." -ForegroundColor Red
                        return
                    }
                }
            }
        } elseif ($vm.State -eq 'Running' -and $ForceStop) {
            Write-Host "Force-stopping VM: $VMName ..." -ForegroundColor Yellow
            Stop-VM -Name $VMName -Force -TurnOff
            Start-Sleep -Seconds 2
        }


        # Decide desired boolean state
        switch ($Action) {
            "Enable"  { $desiredBool = $true }
            "Disable" { $desiredBool = $false }
            "Toggle"  { $desiredBool = -not $currentState }
        }


        if ($desiredBool -eq $currentState) {
            Write-Host "Secure Boot already set to the requested state ($desiredBool). No change necessary." -ForegroundColor Gray
            return
        }


        # Convert boolean to OnOffState enum required by Set-VMFirmware
        $enumValue = if ($desiredBool) { [Microsoft.HyperV.PowerShell.OnOffState]::On } else { [Microsoft.HyperV.PowerShell.OnOffState]::Off }


        Write-Host "Setting Secure Boot to '$enumValue' for VM: $VMName ..." -ForegroundColor Cyan


        # Apply the change (pass the enum, not a boolean)
        Set-VMFirmware -VMName $VMName -EnableSecureBoot $enumValue -ErrorAction Stop


        Write-Host "Secure Boot updated successfully." -ForegroundColor Green


        # Show current state again (normalize to boolean for display)
        $newFirmware = Get-VMFirmware -VMName $VMName -ErrorAction Stop
        $newVal = $null
        if ($newFirmware.PSObject.Properties.Name -contains "EnableSecureBoot") {
            $newVal = $newFirmware.EnableSecureBoot
        } elseif ($newFirmware.PSObject.Properties.Name -contains "SecureBoot") {
            $newVal = $newFirmware.SecureBoot
        }
        if ($newVal -is [Microsoft.HyperV.PowerShell.OnOffState]) {
            $newState = ($newVal -eq [Microsoft.HyperV.PowerShell.OnOffState]::On)
        } else {
            $newState = [bool]$newVal
        }
        Write-Host "VM: $VMName  |  New Secure Boot: $newState" -ForegroundColor Cyan


    } catch {
        Write-Host "ERROR updating Secure Boot for VM '$VMName':" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }
}














function Start-VMAutomated {
    param([string]$VMName)
   
    $vms = Get-VM -Name $VMName | Where-Object { $_.State -ne 'Running' }
    foreach ($vm in $vms) {
        Write-Host "Starting: $($vm.Name)" -ForegroundColor Cyan
        Start-VM -Name $vm.Name
    }
}


function Stop-VMAutomated {
    param([string]$VMName, [switch]$Force)
   
    $vms = Get-VM -Name $VMName | Where-Object { $_.State -eq 'Running' }
    foreach ($vm in $vms) {
        Write-Host "Stopping: $($vm.Name)" -ForegroundColor Cyan
        if ($Force) {
            Stop-VM -Name $vm.Name -Force
        } else {
            Stop-VM -Name $vm.Name
        }
    }
}


# ===========================
# MENU FUNCTIONS
# ===========================


function Show-Menu {
    Write-Host "INFORMATION GATHERING (Read-Only)" -ForegroundColor Cyan
    Write-Host "  1. Get VM Summary (All VMs)" -ForegroundColor White
    Write-Host "  2. Get VM Details (Specific VM)" -ForegroundColor White
    Write-Host ""
    Write-Host "VM OPERATIONS" -ForegroundColor Cyan
    Write-Host "  3. Restore Latest Checkpoint" -ForegroundColor White
    Write-Host "  4. Create Full Clone" -ForegroundColor White
    Write-Host "  5. Adjust VM Resources (CPU/Memory)" -ForegroundColor White
    Write-Host "  6. Delete VM Completely" -ForegroundColor White
    Write-Host "  7. Manage VM ISO" -ForegroundColor White
    Write-Host "  8. Toggle Secure Boot on VM" -ForegroundColor White
    Write-Host ""
    Write-Host "POWER FUNCTIONS" -ForegroundColor Cyan
    Write-Host "  9. Start VM" -ForegroundColor White
    Write-Host " 10. Stop VM" -ForegroundColor White
    Write-Host ""
    Write-Host "  0. Exit" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=========================================="
    Write-Host ""
}


function Menu-GetVMSummary {
    Write-Host "`n=== Get VM Summary ===" -ForegroundColor Cyan
    Write-Host "Leave blank for all VMs, or use wildcard (e.g., web-*)" -ForegroundColor Gray
    $filter = Read-Host "VM Name filter (press Enter for all)"
   
    if ([string]::IsNullOrWhiteSpace($filter)) {
        $filter = "*"
    }
   
    Write-Host ""
    Get-VMSummary -VMName $filter
}


function Menu-GetVMDetails {
    Write-Host "`n=== Get VM Details ===" -ForegroundColor Cyan
   
    # Show available VMs
    Write-Host "`nAvailable VMs:" -ForegroundColor Gray
    Get-VM | Format-Table Name, State -AutoSize
   
    $vmName = Read-Host "`nEnter VM name"
   
    if ([string]::IsNullOrWhiteSpace($vmName)) {
        Write-Host "No VM name provided" -ForegroundColor Red
        return
    }
   
    Get-VMDetails -VMName $vmName
}


function Menu-RestoreCheckpoint {
    Write-Host "`n=== Restore Latest Checkpoint ===" -ForegroundColor Cyan
   
    # Show VMs with checkpoints
    Write-Host "`nVMs with checkpoints:" -ForegroundColor Gray
    $vms = Get-VM
    foreach ($vm in $vms) {
        $cpCount = (Get-VMSnapshot -VM $vm -ErrorAction SilentlyContinue).Count
        if ($cpCount -gt 0) {
            Write-Host "  $($vm.Name) - $cpCount checkpoint(s)" -ForegroundColor White
        }
    }
   
    $vmName = Read-Host "`nEnter VM name"
   
    if ([string]::IsNullOrWhiteSpace($vmName)) {
        Write-Host "No VM name provided" -ForegroundColor Red
        return
    }
   
    Restore-LatestCheckpoint -VMName $vmName
}


function Menu-CloneVM {
    Write-Host "`n=== Create Full Clone ===" -ForegroundColor Cyan
   
    # Show available VMs
    Write-Host "`nAvailable VMs:" -ForegroundColor Gray
    Get-VM | Format-Table Name, State -AutoSize
   
    $sourceVM = Read-Host "`nSource VM name"
    if ([string]::IsNullOrWhiteSpace($sourceVM)) {
        Write-Host "No source VM provided" -ForegroundColor Red
        return
    }
   
    $newName = Read-Host "New VM name"
    if ([string]::IsNullOrWhiteSpace($newName)) {
        Write-Host "No new name provided" -ForegroundColor Red
        return
    }
   
    $destPath = Read-Host "Destination path (e.g., C:\VMs\$newName)"
    if ([string]::IsNullOrWhiteSpace($destPath)) {
        $destPath = "C:\VMs\$newName"
        Write-Host "Using default: $destPath" -ForegroundColor Yellow
    }
   
    New-VMFullClone -SourceVMName $sourceVM -NewVMName $newName -DestinationPath $destPath
}


function Menu-SetResources {
    Write-Host "`n=== Adjust VM Resources ===" -ForegroundColor Cyan
   
    # Show available VMs
    Write-Host "`nAvailable VMs:" -ForegroundColor Gray
    Get-VM | Select-Object Name, ProcessorCount, @{N="MemoryGB";E={[math]::Round($_.MemoryStartup/1GB,2)}} | Format-Table -AutoSize
   
    $vmName = Read-Host "`nEnter VM name"
    if ([string]::IsNullOrWhiteSpace($vmName)) {
        Write-Host "No VM name provided" -ForegroundColor Red
        return
    }
   
    $cpuInput = Read-Host "New CPU count (press Enter to skip)"
    $memInput = Read-Host "New Memory in GB (press Enter to skip)"
   
    $cpuCount = $null
    $memGB = $null
   
    if (-not [string]::IsNullOrWhiteSpace($cpuInput)) {
        $cpuCount = [int]$cpuInput
    }
   
    if (-not [string]::IsNullOrWhiteSpace($memInput)) {
        $memGB = [int]$memInput
    }
   
    if ($cpuCount -or $memGB) {
        Set-VMResources -VMName $vmName -CPUCount $cpuCount -MemoryGB $memGB
    } else {
        Write-Host "No changes specified" -ForegroundColor Yellow
    }
}


function Menu-DeleteVM {
    Write-Host "`n=== Delete VM Completely ===" -ForegroundColor Cyan
   
    # Show available VMs
    Write-Host "`nAvailable VMs:" -ForegroundColor Gray
    Get-VM | Format-Table Name, State -AutoSize
   
    Write-Host "WARNING: This will permanently delete the VM and all its files!" -ForegroundColor Red
   
    $vmName = Read-Host "`nEnter VM name to delete"
   
    if ([string]::IsNullOrWhiteSpace($vmName)) {
        Write-Host "No VM name provided" -ForegroundColor Red
        return
    }
   
    Remove-VMComplete -VMName $vmName
}


function Menu-ManageISO {
    Write-Host "`n=== Attach / Detach ISO (Virtual DVD) ===" -ForegroundColor Cyan


    # Show available VMs
    Write-Host "`nAvailable VMs:" -ForegroundColor Gray
    Get-VM | Format-Table Name, State, Generation -AutoSize


    $vmName = Read-Host "`nEnter VM name"
    if ([string]::IsNullOrWhiteSpace($vmName)) {
        Write-Host "No VM name provided" -ForegroundColor Red
        return
    }


    # Validate VM exists
    try {
        $vm = Get-VM -Name $vmName -ErrorAction Stop
    } catch {
        Write-Host "VM '$vmName' not found." -ForegroundColor Red
        return
    }


    Write-Host "`nChoose action:" -ForegroundColor Gray
    Write-Host "  1) Attach ISO (mount an ISO to the VM's DVD drive)" -ForegroundColor White
    Write-Host "  2) Replace ISO (replace currently mounted ISO or add drive then mount)" -ForegroundColor White
    Write-Host "  3) Detach ISO (unmount and optionally remove the virtual DVD drive)" -ForegroundColor White


    $choice = Read-Host "`nSelect 1, 2, or 3"
    switch ($choice) {
        '1' { $action = "Attach" }
        '2' { $action = "Replace" }
        '3' { $action = "Detach" }
        default {
            Write-Host "Invalid selection." -ForegroundColor Red
            return
        }
    }


    $isoPath = $null
    if ($action -ne 'Detach') {
        $isoPath = Read-Host "Full path to ISO on host (e.g., C:\ISOs\installer.iso)"
        if ([string]::IsNullOrWhiteSpace($isoPath)) {
            Write-Host "No ISO path provided. Aborting." -ForegroundColor Red
            return
        }
    }


    # If VM is running, ask about forcing/hot-plug
    $force = $false
    if ($vm.State -eq 'Running') {
        $forceResp = Read-Host "VM is running. Attempt hot-plug / continue while running? (Y/N)"
        if ($forceResp -eq 'Y') { $force = $true }
    }


    Set-VMIso -VMName $vmName -Action $action -ISOPath $isoPath -Force:($force)
}




function Menu-ToggleSecureBoot {
    Write-Host "`n=== Toggle Secure Boot (Generation 2 VMs) ===" -ForegroundColor Cyan


    # Show available VMs (including generation)
    Write-Host "`nAvailable VMs:" -ForegroundColor Gray
    Get-VM | Select-Object Name, State, Generation | Format-Table -AutoSize


    $vmName = Read-Host "`nEnter VM name"
    if ([string]::IsNullOrWhiteSpace($vmName)) {
        Write-Host "No VM name provided" -ForegroundColor Red
        return
    }


    # Validate VM exists
    try {
        $vm = Get-VM -Name $vmName -ErrorAction Stop
    } catch {
        Write-Host "VM '$vmName' not found." -ForegroundColor Red
        return
    }


    if ($vm.Generation -ne 2) {
        Write-Host "Note: Secure Boot is only supported on Generation 2 VMs. '$vmName' is generation $($vm.Generation)." -ForegroundColor Yellow
        return
    }


    Write-Host "`nChoose action:" -ForegroundColor Gray
    Write-Host "  1) Enable Secure Boot" -ForegroundColor White
    Write-Host "  2) Disable Secure Boot" -ForegroundColor White
    Write-Host "  3) Toggle Secure Boot (flip current state)" -ForegroundColor White


    $choice = Read-Host "`nSelect 1, 2, or 3"
    switch ($choice) {
        '1' { $action = "Enable" }
        '2' { $action = "Disable" }
        '3' { $action = "Toggle" }
        default {
            Write-Host "Invalid selection." -ForegroundColor Red
            return
        }
    }


    # Ask whether to force-stop if VM is running
    $forceStop = $false
    if ($vm.State -eq 'Running') {
        $stopResp = Read-Host "VM is running. Stop it automatically if required? (Y/N)"
        if ($stopResp -eq 'Y') { $forceStop = $true }
    }


    Toggle-VMSecureBoot -VMName $vmName -Action $action -ForceStop:($forceStop)
}




















function Menu-StartVM {
    Write-Host "`n=== Start VM ===" -ForegroundColor Cyan
   
    # Show stopped VMs
    Write-Host "`nStopped VMs:" -ForegroundColor Gray
    Get-VM | Where-Object {$_.State -ne 'Running'} | Format-Table Name, State -AutoSize
   
    $vmName = Read-Host "`nEnter VM name (or wildcard like web-*)"
   
    if ([string]::IsNullOrWhiteSpace($vmName)) {
        Write-Host "No VM name provided" -ForegroundColor Red
        return
    }
   
    Start-VMAutomated -VMName $vmName
}


function Menu-StopVM {
    Write-Host "`n=== Stop VM ===" -ForegroundColor Cyan
   
    # Show running VMs
    Write-Host "`nRunning VMs:" -ForegroundColor Gray
    Get-VM | Where-Object {$_.State -eq 'Running'} | Format-Table Name -AutoSize
   
    $vmName = Read-Host "`nEnter VM name (or wildcard like web-*)"
   
    if ([string]::IsNullOrWhiteSpace($vmName)) {
        Write-Host "No VM name provided" -ForegroundColor Red
        return
    }
   
    $force = Read-Host "Force shutdown? (Y/N)"
   
    if ($force -eq 'Y') {
        Stop-VMAutomated -VMName $vmName -Force
    } else {
        Stop-VMAutomated -VMName $vmName
    }
}


# ===========================
# MAIN MENU LOOP
# ===========================


function Start-HyperVAutomation {
   
    do {
        Show-Menu
        $choice = Read-Host "Select an option (0-10)"
       
        Write-Host ""
       
        switch ($choice) {
            '1' { Menu-GetVMSummary }
            '2' { Menu-GetVMDetails }
            '3' { Menu-RestoreCheckpoint }
            '4' { Menu-CloneVM }
            '5' { Menu-SetResources }
            '6' { Menu-DeleteVM }
            '7' { Menu-ManageISO }
            '8' { Menu-ToggleSecureBoot }
            '9' { Menu-StartVM }
            '10' { Menu-StopVM }
            '0' {
                Write-Host "Exiting..." -ForegroundColor Yellow
                break
            }
            default {
                Write-Host "Invalid selection. Please choose 0-10" -ForegroundColor Red
            }
        }
       
        if ($choice -ne '0') {
            Write-Host ""
            Read-Host "Press Enter to return to menu"
        }
       
    } while ($choice -ne '0')
   
    Write-Host ""
    Write-Host "Closing script..." -ForegroundColor Green
    Write-Host ""
}


# ===========================
# START THE SCRIPT
# ===========================


Start-HyperVAutomation






