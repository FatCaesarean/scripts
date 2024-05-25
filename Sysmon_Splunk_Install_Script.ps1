# Define credentials
$adminUsername = "User"
$adminPassword = ConvertTo-SecureString "user" -AsPlainText -Force
$adminCredential = New-Object System.Management.Automation.PSCredential ($adminUsername, $adminPassword)

# Install Sysmon and start at boot
Write-Host "Downloading and installing Sysmon..."
Invoke-WebRequest -Uri https://download.sysinternals.com/files/Sysmon.zip -OutFile "$env:TEMP\Sysmon.zip"
Expand-Archive -Path "$env:TEMP\Sysmon.zip" -DestinationPath "$env:TEMP\Sysmon"
Invoke-WebRequest -Uri https://raw.githubusercontent.com/Neo23x0/sysmon-config/master/sysmonconfig-export.xml -OutFile "$env:TEMP\sysmonconfig.xml"
Start-Process -FilePath "$env:TEMP\Sysmon\Sysmon.exe" -ArgumentList "-accepteula -i $env:TEMP\sysmonconfig.xml"

# Script to run service as admin
function Run-AsAdmin {
    param (
        [string]$scriptBlock
    )
    $command = "powershell -Command & { $scriptBlock }"
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "powershell.exe"
    $startInfo.Arguments = $command
    $startInfo.Verb = "runas"
    $startInfo.UseShellExecute = $true
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $process.WaitForExit()
    return $process.ExitCode
}

# Set Sysmon service to start automatically
$serviceScript = "Set-Service -Name 'Sysmon' -StartupType Automatic"
Run-AsAdmin -scriptBlock $serviceScript

# Verify Sysmon installation
if (Get-Process -Name sysmon -ErrorAction SilentlyContinue) {
    Write-Host "Sysmon installed and running with the specified configuration."
} else {
    Write-Host "Sysmon installation failed or it is not running."
    exit 1
}

# Prompt user to install Splunk
$installSplunk = Read-Host "Do you wish to install Splunk Forwarder? (y/n)"
if ($installSplunk -ne 'y') {
    Write-Host "Exiting script as per user choice."
    exit 0
}

# Install Splunk Forwarder
Write-Host "Downloading and installing Splunk Universal Forwarder..."
Invoke-WebRequest -Uri "https://download.splunk.com/products/universalforwarder/releases/9.2.1/windows/splunkforwarder-9.2.1-78803f08aabb-x64-release.msi" -OutFile $env:TEMP\splunkforwarder.msi

# Used to install Universal Forwarder in Windows.

Start-Transcript -Path "C:\Program Files\SplunkForwarder\Forwarder.log"
Write-Host "Installing Splunk Universal Forwarder"

# Install Universal forwarder without starting splunk service
Write-Host "Setup running. Please wait...!!"
$return = (Start-Process msiexec.exe -ArgumentList '/i "$env:TEMP\splunkforwarder.msi" LAUNCHSPLUNK=0 AGREETOLICENSE=Yes INSTALLDIR="C:\Program Files\SplunkUniversalForwarder" DEPLOYMENT_SERVER="192.168.90.150:8089" /quiet' -PassThru -wait)
if ($return.ExitCode -eq 0) { Write-Host "UF setup completed"} 
else
{Write-Host "UF Installation Terminated" 
Write-Host "Starting Splunkd..."
Get-Service splunkd | Start-Service
Write-Host "Splunkd Started."
# Read-Host -Prompt "Press Enter to exit the setup"
Exit}

Read-Host -Prompt "Press Enter to continue"

# Add SSL configurations
#$DCsourceRoot = $(get-location).Path;
#$DCsourceRoot = $(get-location).Path + "\<Certificate-Name>"
#$DCdestroot = "C:\Program Files\SplunkUniversalForwarder\etc\auth\"
#Copy-Item -Path $DCsourceRoot -Destination $DCdestroot -Recurse -force

# Write-Host "SSL Configuration Applied"

# Change Admin password 
$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = 'C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe'
$pinfo.RedirectStandardError = $true
$pinfo.RedirectStandardOutput = $true
$pinfo.UseShellExecute = $false
$pinfo.Arguments = "edit user admin -password Password1 -auth admin:admin"
$p = New-Object System.Diagnostics.Process
$p.StartInfo = $pinfo
$p.Start() | Out-Null

Write-Host "Password Changed Succesfully"

# Set service recovery options
Write-Host "Setting service recovery options..."
sc.exe failure SplunkForwarder reset= 0 actions= restart\60000\restart\60000\\

# Configure Splunk Forwarder
Write-Host "Configuring Splunk Forwarder..."
& "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe" create deployment-client
& "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe" set deploy-poll 192.168.90.150:8089 
& "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe" add forward-server 192.168.90.150:9997 
& "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe" add monitor "C:\Windows\System32\winevt\Logs\Security.evtx"
& "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe" add monitor "C:\Windows\System32\winevt\Logs\System.evtx"
& "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe" add monitor "C:\Windows\System32\winevt\Logs\Application.evtx" 
& "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe" add monitor "C:\Windows\System32\winevt\Logs\Microsoft-Windows-Sysmon%4Operational.evtx"

Write-Host "Splunk Forwarder installation and configuration completed."

# Start Splunk Universal forwarder service
Write-Host "Starting Splunkforwarder..."
Get-Service splunkFor* | Start-Service

Write-Host "Splunkforwarder started"