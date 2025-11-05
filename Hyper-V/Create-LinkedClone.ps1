<#
.SYNOPSIS
    Automates the creation of a HyperV Linked Clone (Differencing Disk VM)


.DESCRIPTION
    This script creates a new VM using a differencing disk that points to a parent base image.
    The parent disk should be read-only to prevent corruption.
#>


param(
    [Parameter(Mandatory=$true)]
    [string]$ParentVHDPath,
   
    [Parameter(Mandatory=$true)]
    [string]$ChildVMName,
   
    [Parameter(Mandatory=$true)]
    [string]$ChildVHDPath,
   
    [Parameter(Mandatory=$true)]
    [string]$VMSwitch,
   
    [Parameter(Mandatory=$false)]
    [int64]$Memory = 2GB,
   
    [Parameter(Mandatory=$false)]
    [int]$CPUCount = 2
)


# Function to write colored output
function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    switch($Type) {
        "Success" { Write-Host $Message -ForegroundColor Green }
        "Error"   { Write-Host $Message -ForegroundColor Red }
        "Warning" { Write-Host $Message -ForegroundColor Yellow }
        default   { Write-Host $Message -ForegroundColor Cyan }
    }
}


Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  HyperV Linked Clone Creation Script" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta


# Validate parent disk exists
Write-Status "Validating parent disk..." -Type "Info"
if (-not (Test-Path $ParentVHDPath)) {
    Write-Status "Error: Parent VHD not found at $ParentVHDPath" -Type "Error"
    exit 1
}
Write-Status "Parent disk found" -Type "Success"


# Ensure parent disk is read-only
Write-Status "Checking parent disk read-only status..." -Type "Info"
$parentFile = Get-Item $ParentVHDPath
if (-not $parentFile.IsReadOnly) {
    Write-Status "Warning: Parent disk is not read-only. Setting read-only attribute..." -Type "Warning"
    Set-ItemProperty -Path $ParentVHDPath -Name IsReadOnly -Value $true
    Write-Status "Parent disk is now read-only" -Type "Success"
} else {
    Write-Status "Parent disk is already read-only" -Type "Success"
}


# Create directory for child VHD if it doesn't exist
$childDir = Split-Path -Parent $ChildVHDPath
if (-not (Test-Path $childDir)) {
    Write-Status "Creating directory: $childDir" -Type "Info"
    New-Item -ItemType Directory -Path $childDir -Force | Out-Null
    Write-Status "Directory created" -Type "Success"
}


# Check if child VHD already exists
if (Test-Path $ChildVHDPath) {
    Write-Status "Error: Child VHD already exists at $ChildVHDPath" -Type "Error"
    Write-Status "Please choose a different path or remove the existing file." -Type "Error"
    exit 1
}


# Create differencing disk
Write-Status "Creating differencing disk: $ChildVHDPath" -Type "Info"
try {
    New-VHD -Path $ChildVHDPath -ParentPath $ParentVHDPath -Differencing | Out-Null
    Write-Status "Differencing disk created successfully" -Type "Success"
} catch {
    Write-Status "Error creating differencing disk: $_" -Type "Error"
    exit 1
}


# Verify differencing disk creation
$diskInfo = Get-VHD -Path $ChildVHDPath
Write-Status "Differencing disk size: $([math]::Round($diskInfo.FileSize / 1MB, 2)) MB" -Type "Info"


# Check if VM already exists
if (Get-VM -Name $ChildVMName -ErrorAction SilentlyContinue) {
    Write-Status "Error: VM '$ChildVMName' already exists." -Type "Error"
    Write-Status "Please choose a different name or remove the existing VM." -Type "Error"
    # Clean up the VHD we just created
    Remove-Item $ChildVHDPath -Force
    exit 1
}


# Verify virtual switch exists
$switch = Get-VMSwitch -Name $VMSwitch -ErrorAction SilentlyContinue
if (-not $switch) {
    Write-Status "Error: Virtual switch '$VMSwitch' not found." -Type "Error"
    Write-Status "Available switches:" -Type "Info"
    Get-VMSwitch | Select-Object Name, SwitchType | Format-Table
    # Clean up the VHD we just created
    Remove-Item $ChildVHDPath -Force
    exit 1
}


# Create new VM
Write-Status "Creating VM: $ChildVMName" -Type "Info"
try {
    New-VM -Name $ChildVMName `
           -MemoryStartupBytes $Memory `
           -VHDPath $ChildVHDPath `
           -Generation 2 `
           -SwitchName $VMSwitch | Out-Null
   
    Write-Status "VM created successfully" -Type "Success"
} catch {
    Write-Status "Error creating VM: $_" -Type "Error"
    # Clean up the VHD we just created
    Remove-Item $ChildVHDPath -Force
    exit 1
}


# Configure VM settings
Write-Status "Configuring VM settings..." -Type "Info"


# Set CPU count
Set-VMProcessor -VMName $ChildVMName -Count $CPUCount
Write-Status "CPU count set to $CPUCount" -Type "Success"


# Disable secure boot (important for Linux VMs and some Windows scenarios)
Set-VMFirmware -VMName $ChildVMName -EnableSecureBoot Off
Write-Status "Secure boot disabled" -Type "Success"


# Optional: Enable dynamic memory
# Uncomment the following lines to enable dynamic memory
# Set-VMMemory -VMName $ChildVMName -DynamicMemoryEnabled $true -MinimumBytes 512MB -MaximumBytes ($Memory * 2)
# Write-Status "Dynamic memory enabled" -Type "Success"


Write-Status "`nVM configuration complete!" -Type "Success"


# Display VM information
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "         VM Information" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta


$vm = Get-VM -Name $ChildVMName
$vmDisk = Get-VHD -Path $ChildVHDPath


Write-Host "`nVirtual Machine:" -ForegroundColor Yellow
Write-Host "  Name:              $($vm.Name)"
Write-Host "  State:             $($vm.State)"
Write-Host "  Memory (MB):       $($vm.MemoryStartup / 1MB)"
Write-Host "  CPU Count:         $($vm.ProcessorCount)"
Write-Host "  Generation:        $($vm.Generation)"
Write-Host "  Virtual Switch:    $VMSwitch"


Write-Host "`nVirtual Disk:" -ForegroundColor Yellow
Write-Host "  Path:              $ChildVHDPath"
Write-Host "  Type:              $($vmDisk.VhdType)"
Write-Host "  Current Size:      $([math]::Round($vmDisk.FileSize / 1MB, 2)) MB"
Write-Host "  Max Size:          $([math]::Round($vmDisk.Size / 1GB, 2)) GB"
Write-Host "  Parent Disk:       $($vmDisk.ParentPath)"


Write-Host "`n========================================`n" -ForegroundColor Magenta


# Ask if user wants to start the VM
$response = Read-Host "Do you want to start the VM now? (Y/N)"
if ($response -eq 'Y' -or $response -eq 'y') {
    Write-Status "Starting VM..." -Type "Info"
    Start-VM -Name $ChildVMName
    Start-Sleep -Seconds 2
    $vmState = (Get-VM -Name $ChildVMName).State
    Write-Status "VM started successfully! Current state: $vmState" -Type "Success"
} else {
    Write-Status "VM created but not started." -Type "Info"
    Write-Host "To start the VM later, use: " -NoNewline
    Write-Host "Start-VM -Name '$ChildVMName'" -ForegroundColor Yellow
}


Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  Linked Clone Creation Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Magenta
