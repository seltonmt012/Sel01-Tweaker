#Requires -Version 5.1
<#
  new-testvm.ps1 - spin up a clean Windows 11 Hyper-V VM for testing Sel01-Tweaker.

  Fully unattended: builds a seed disk holding autounattend.xml, creates a Gen2
  VM (vTPM + Secure Boot), boots the install ISO, and Windows installs itself to a
  local-admin desktop with autologon - no clicking. Then poll with -WaitDesktop and
  snapshot with -Checkpoint so you can always roll back to a clean build.

  Host note: bypass keys (TPM/CPU/SecureBoot/RAM) are injected so it also installs
  on hosts whose CPU isn't on Microsoft's Win11 list (e.g. 9th-gen Intel).

  Usage:
    .\tools\new-testvm.ps1 -Iso C:\Sel01TestVM\win11.iso            # create + start
    .\tools\new-testvm.ps1 -WaitDesktop                              # block until desktop
    .\tools\new-testvm.ps1 -Checkpoint clean-desktop                 # snapshot
    .\tools\new-testvm.ps1 -RevertTo clean-desktop                   # roll back + start
#>
[CmdletBinding()]
param(
    [string]$Name   = 'Sel01-Win11-Test',
    [string]$Iso,
    [string]$Root   = 'C:\Sel01TestVM',
    [int]   $CpuCount = 4,
    [int64] $StartupMemory = 4GB,
    [int64] $MaxMemory     = 8GB,
    [int64] $DiskSize      = 64GB,
    [string]$AdminUser = 'Tester',
    [string]$AdminPass = 'Test1234!',
    [string]$Switch    = 'Default Switch',
    [switch]$WaitDesktop,
    [string]$Checkpoint,
    [string]$RevertTo
)
$ErrorActionPreference = 'Stop'
function Step($m){ Write-Host "==> $m" -ForegroundColor Cyan }

# --------- standalone actions ------------------------------------------------
if ($Checkpoint) {
    Step "checkpoint '$Checkpoint' on $Name"
    Checkpoint-VM -Name $Name -SnapshotName $Checkpoint
    Write-Host "DONE checkpoint '$Checkpoint'" -ForegroundColor Green
    return
}
if ($RevertTo) {
    Step "restore '$RevertTo' on $Name + start"
    Restore-VMSnapshot -VMName $Name -Name $RevertTo -Confirm:$false
    Start-VM -Name $Name
    Write-Host "DONE reverted to '$RevertTo'" -ForegroundColor Green
    return
}
if ($WaitDesktop) {
    Step "waiting for $Name to reach desktop (heartbeat OkApplicationsHealthy)"
    $stable = 0
    while ($true) {
        Start-Sleep -Seconds 20
        $vm = Get-VM -Name $Name
        $hb = "$($vm.Heartbeat)"
        Write-Host ("    state={0} heartbeat={1} uptime={2}" -f $vm.State,$hb,$vm.Uptime)
        if ($hb -like 'OkApplicationsHealthy*') { $stable++ } else { $stable = 0 }
        if ($stable -ge 6) { break }   # ~2 min stable -> at desktop, autologon done
    }
    Write-Host "DONE: $Name is at the desktop" -ForegroundColor Green
    return
}

# --------- create the VM -----------------------------------------------------
if (-not $Iso)            { throw "Provide -Iso <path to win11.iso>" }
if (-not (Test-Path $Iso)){ throw "ISO not found: $Iso" }
New-Item -ItemType Directory -Force -Path $Root | Out-Null

if (Get-VM -Name $Name -ErrorAction SilentlyContinue) {
    throw "VM '$Name' already exists. Remove it first: Remove-VM -Name '$Name' -Force; then delete $Root\*.vhdx"
}

# 1) autounattend.xml (amd64) - bypass checks, wipe disk, local admin, autologon
$pass = $AdminPass
$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"><Order>1</Order><Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"><Order>2</Order><Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"><Order>3</Order><Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"><Order>4</Order><Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassCPUCheck /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"><Order>5</Order><Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassStorageCheck /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"><Order>6</Order><Path>reg add HKLM\SYSTEM\Setup\MoSetup /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
      </RunSynchronous>
      <DiskConfiguration>
        <Disk wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
          <DiskID>0</DiskID>
          <WillWipeDisk>true</WillWipeDisk>
          <CreatePartitions>
            <CreatePartition wcm:action="add"><Order>1</Order><Type>EFI</Type><Size>300</Size></CreatePartition>
            <CreatePartition wcm:action="add"><Order>2</Order><Type>MSR</Type><Size>128</Size></CreatePartition>
            <CreatePartition wcm:action="add"><Order>3</Order><Type>Primary</Type><Extend>true</Extend></CreatePartition>
          </CreatePartitions>
          <ModifyPartitions>
            <ModifyPartition wcm:action="add"><Order>1</Order><PartitionID>1</PartitionID><Format>FAT32</Format><Label>System</Label></ModifyPartition>
            <ModifyPartition wcm:action="add"><Order>2</Order><PartitionID>2</PartitionID></ModifyPartition>
            <ModifyPartition wcm:action="add"><Order>3</Order><PartitionID>3</PartitionID><Format>NTFS</Format><Label>Windows</Label><Letter>C</Letter></ModifyPartition>
          </ModifyPartitions>
        </Disk>
      </DiskConfiguration>
      <ImageInstall>
        <OSImage>
          <InstallTo><DiskID>0</DiskID><PartitionID>3</PartitionID></InstallTo>
          <InstallToAvailablePartition>false</InstallToAvailablePartition>
          <WillShowUI>OnError</WillShowUI>
          <InstallFrom><MetaData wcm:action="add"><Key>/IMAGE/NAME</Key><Value>Windows 11 Pro</Value></MetaData></InstallFrom>
        </OSImage>
      </ImageInstall>
      <UserData>
        <AcceptEula>true</AcceptEula>
        <ProductKey><Key>VK7JG-NPHTM-C97JM-9MPGT-3V66T</Key><WillShowUI>Never</WillShowUI></ProductKey>
      </UserData>
    </component>
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage><UILanguage>en-US</UILanguage></SetupUILanguage>
      <InputLocale>en-US</InputLocale><SystemLocale>en-US</SystemLocale><UILanguage>en-US</UILanguage><UserLocale>en-US</UserLocale>
    </component>
  </settings>
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ComputerName>SEL01-TEST</ComputerName>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>en-US</InputLocale><SystemLocale>en-US</SystemLocale><UILanguage>en-US</UILanguage><UserLocale>en-US</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
        <UnattendEnableRetailDemo>false</UnattendEnableRetailDemo>
      </OOBE>
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <Name>$AdminUser</Name><Group>Administrators</Group><DisplayName>$AdminUser</DisplayName>
            <Password><Value>$pass</Value><PlainText>true</PlainText></Password>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>
      <AutoLogon>
        <Enabled>true</Enabled><LogonCount>999</LogonCount><Username>$AdminUser</Username>
        <Password><Value>$pass</Value><PlainText>true</PlainText></Password>
      </AutoLogon>
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
          <Order>1</Order><CommandLine>reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f</CommandLine>
        </SynchronousCommand>
      </FirstLogonCommands>
    </component>
  </settings>
</unattend>
"@

# 2) build seed VHDX (FAT32) holding autounattend.xml at its root
Step 'building seed disk with autounattend.xml'
$seed = Join-Path $Root "$Name-seed.vhdx"
if (Test-Path $seed) { Remove-Item $seed -Force }
$v = New-VHD -Path $seed -SizeBytes 256MB -Dynamic
$d = (Mount-VHD -Path $seed -Passthru | Get-Disk)
Initialize-Disk -Number $d.Number -PartitionStyle MBR -Confirm:$false
$part = New-Partition -DiskNumber $d.Number -UseMaximumSize -AssignDriveLetter
Format-Volume -DriveLetter $part.DriveLetter -FileSystem FAT32 -NewFileSystemLabel 'SEED' -Confirm:$false | Out-Null
Set-Content -Path ("{0}:\autounattend.xml" -f $part.DriveLetter) -Value $xml -Encoding UTF8
Dismount-VHD -Path $seed

# 3) create the Gen2 VM
Step "creating VM '$Name'"
$os = Join-Path $Root "$Name-os.vhdx"
if (Test-Path $os) { Remove-Item $os -Force }
$vm = New-VM -Name $Name -Generation 2 -MemoryStartupBytes $StartupMemory -NewVHDPath $os -NewVHDSizeBytes $DiskSize -SwitchName $Switch -Path $Root
Set-VMMemory -VMName $Name -DynamicMemoryEnabled $true -MinimumBytes 2GB -StartupBytes $StartupMemory -MaximumBytes $MaxMemory
Set-VMProcessor -VMName $Name -Count $CpuCount
Set-VM -VMName $Name -AutomaticCheckpointsEnabled $false -CheckpointType Standard

# vTPM + Secure Boot so Win11 is happy
$kp = Get-VMKeyProtector -VMName $Name
if (-not $kp -or $kp.Length -le 4) { Set-VMKeyProtector -VMName $Name -NewLocalKeyProtector }
Enable-VMTPM -VMName $Name
Set-VMFirmware -VMName $Name -EnableSecureBoot On -SecureBootTemplate MicrosoftWindows

# attach install ISO + seed, boot from DVD first
Add-VMDvdDrive -VMName $Name -Path $Iso
Add-VMHardDiskDrive -VMName $Name -Path $seed
$dvd = Get-VMDvdDrive -VMName $Name
Set-VMFirmware -VMName $Name -FirstBootDevice $dvd

Step "starting VM '$Name' (unattended install begins)"
Start-VM -Name $Name
Write-Host "DONE: VM created and started. Now run:  .\tools\new-testvm.ps1 -WaitDesktop" -ForegroundColor Green
