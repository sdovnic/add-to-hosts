if ($PSVersionTable.PSVersion.Major -lt 3) {
    [string] $PSScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
}

if ($PSVersionTable.PSVersion.Major -lt 3) {
    [string] $PSCommandPath = $MyInvocation.MyCommand.Definition
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    [bool] $Elevate = $true
    if ($Elevate) {
        Start-Process -FilePath "powershell" -WindowStyle Hidden -WorkingDirectory $PSScriptRoot -Verb runAs `
                      -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File $PSCommandPath $args"
        return
    }
}

Import-LocalizedData -BaseDirectory $PSScriptRoot\Locales -BindingVariable Messages

Import-Module -Name (Join-Path -Path $PSScriptRoot\Modules -ChildPath Show-Balloon)
Import-Module -Name (Join-Path -Path $PSScriptRoot\Modules -ChildPath Add-ShortCut)
Import-Module -Name (Join-Path -Path $PSScriptRoot\Modules -ChildPath Remove-ShortCut)

if ($args.Length -gt 0) {
    [string] $TaskName = "add-to-hosts-log-event"
    [string] $TaskScript = (Join-Path -Path $PSScriptRoot -ChildPath "add-to-hosts-event.ps1")
    [string] $TaskDescription = $Messages."Changes the given hosts entry, requires {0}." -f $TaskScript
    [string] $TaskCommand = (Join-Path -Path $PSHOME -ChildPath "powershell.exe")
    [string] $TaskArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$TaskScript`""
    [string] $TaskFile = (Join-Path -Path $PSScriptRoot -ChildPath "$TaskName.xml")
    [string] $TaskTemplate = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2017-11-15T21:23:48.0026802</Date>
    <Author>Rally Vincent</Author>
    <URI></URI>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and EventID=10000]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>false</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command></Command>
      <Arguments></Arguments>
    </Exec>
  </Actions>
</Task>
'@
    if ($args[0].Contains("remove")) {
        if (Get-Command -Name Get-ScheduledTask -ErrorAction SilentlyContinue) {
            if (Get-ScheduledTask -TaskName $TaskName -TaskPath "\" -ErrorAction SilentlyContinue) {
                Unregister-ScheduledTask -TaskName $TaskName -TaskPath "\" -Confirm:$False
            }
        } else {
            Write-Warning -Message $Messages."Get-ScheduledTask not supported, using Schtasks."
            $Query = schtasks /Query /TN "\$TaskName" | Out-String
            if ($Query.Contains($TaskName)) {
                [array] $ArgumentList = @("/Delete", "/TN `"\$TaskName`"", "/F")
                Start-Process -FilePath "schtasks" -ArgumentList $ArgumentList -WindowStyle Hidden
            }
        }
        $Username = Get-WMIObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty Username | Split-Path -Leaf
        if (-not ($env:USERNAME -eq $Username)) {
            $Path = [Environment]::GetFolderPath("StartMenu") -replace $env:USERNAME, $Username
        } else {
            $Path = [Environment]::GetFolderPath("StartMenu")
        }
        Remove-ShortCut -Link (Join-Path -Path $Path -ChildPath ("{0}.lnk" -f $Messages."Add to hosts"))
        Add-Type -AssemblyName System.Windows.Forms
        Show-Balloon -TipTitle $Messages."Add to hosts" -TipText $Messages."Add to hosts event removed."
    } else {
        if (Get-Command -Name Get-ScheduledTask -ErrorAction SilentlyContinue) {
            if (Get-ScheduledTask -TaskName $TaskName -TaskPath "\" -ErrorAction SilentlyContinue) {
                Write-Warning -Message $Messages."Task already exist!"
            } else {
                $TaskTemplate = $TaskTemplate -replace "<Description>(.*)</Description>", "<Description>$TaskDescription</Description>"
                $TaskTemplate = $TaskTemplate -replace "<URI>(.*)</URI>", "<URI>\$TaskName</URI>"
                $TaskTemplate = $TaskTemplate -replace "<Command>(.*)</Command>", "<Command>$TaskCommand</Command>"
                $TaskTemplate = $TaskTemplate -replace "<Arguments>(.*)</Arguments>", "<Arguments>$TaskArguments</Arguments>"
                Set-Content -Path $TaskFile -Value $TaskTemplate
                Start-Process -FilePath "schtasks" -ArgumentList ("/Create", "/TN `"\$TaskName`"", "/XML `"$PSScriptRoot\$TaskName.xml`"") -WindowStyle Hidden -Wait
                Remove-Item -Path $TaskFile
            }
        } else {
            Write-Warning -Message $Messages."Get-ScheduledTask not supported, using Schtasks."
            $Query = schtasks /Query /TN "\$TaskName" | Out-String
            if ($Query.Contains($TaskName)) {
                Write-Warning -Message $Messages."Task already exist!"
            } else {
                $TaskTemplate = $TaskTemplate -replace "<Description>(.*)</Description>", "<Description>$TaskDescription</Description>"
                $TaskTemplate = $TaskTemplate -replace "<URI>(.*)</URI>", "<URI>\$TaskName</URI>"
                $TaskTemplate = $TaskTemplate -replace "<Command>(.*)</Command>", "<Command>$TaskCommand</Command>"
                $TaskTemplate = $TaskTemplate -replace "<Arguments>(.*)</Arguments>", "<Arguments>$TaskArguments</Arguments>"
                Set-Content -Path $TaskFile -Value $TaskTemplate
                Start-Process -FilePath "schtasks" -ArgumentList ("/Create", "/TN `"\$TaskName`"", "/XML `"$PSScriptRoot\$TaskName.xml`"") -WindowStyle Hidden -Wait
                Remove-Item -Path $TaskFile
            }
        }
        $Username = Get-WMIObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty Username | Split-Path -Leaf
        if (-not ($env:USERNAME -eq $Username)) {
            $Path = [Environment]::GetFolderPath("StartMenu") -replace $env:USERNAME, $Username
        } else {
            $Path = [Environment]::GetFolderPath("StartMenu")
        }
        Add-ShortCut -Link (Join-Path -Path $Path -ChildPath ("{0}.lnk" -f $Messages."Add to hosts")) `
                     -TargetPath (Join-Path -Path $PSHOME -ChildPath "powershell.exe") `
                     -Arguments "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSScriptRoot\add-to-hosts.ps1`"" `
                     -IconLocation "%SystemRoot%\system32\imageres.dll,20" `
                     -Description $Messages."Change hosts file."
        Add-Type -AssemblyName System.Windows.Forms
        Show-Balloon -TipTitle $Messages."Add to hosts" -TipText $Messages."Add to hosts event installed."
    }
}