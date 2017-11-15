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
                      -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File $PSCommandPath"
        return
    }
}

Import-LocalizedData -BaseDirectory $PSScriptRoot\Locales -BindingVariable Messages

Import-Module -Name (Join-Path -Path $PSScriptRoot\Modules -ChildPath Show-Balloon)

[string] $ConfigFile = (Join-path -Path $PSScriptRoot -ChildPath "add-to-hosts-config.xml")
[xml] $Config = Get-Content -Path $ConfigFile
[ipaddress] $IPv4Address = $Config.Settings.IPv4Address
[string ]$DomainName = $Config.Settings.DomainName

function ChangeHostsFile {
    [CmdLetBinding()]
    param(
        [parameter(Mandatory=$true,ParameterSetName="Network")] [string][ValidateSet("Internal", "External", "Default")] $Network = "External"
    )
    Begin {
        $HostsFile = Get-Content -Path (Join-Path -Path $env:windir -ChildPath "system32\drivers\etc\hosts") -Encoding Ascii
    }
    Process {
        if ($Network.Contains("Internal")) {
            if (-not ($HostsFile -match $IPv4Address.IPAddressToString)) {
                $HostsFile = $HostsFile + ("{0} {1}" -f ($IPv4Address.IPAddressToString, $DomainName))
            }
        } elseif ($Network.Contains("External")) {
            $HostsFile = $HostsFile -replace ("{0} {1}" -f $IPv4Address.IPAddressToString, $DomainName), ""
        } else {
            $HostsFile = Get-Content -Path (Join-path -Path $PSScriptRoot -ChildPath "hosts")
        }
    }
    End {
        $HostsFile | Set-Content -Path (Join-Path -Path $env:windir -ChildPath "system32\drivers\etc\hosts") -Encoding Ascii
    }
}

$HostsFile = Get-Content -Path (Join-Path -Path $env:windir -ChildPath "system32\drivers\etc\hosts") -Encoding Ascii

Add-Type -AssemblyName System.Windows.Forms
if ($HostsFile -match $DomainName) {
    $Result = [System.Windows.Forms.MessageBox]::Show(
        ($Messages."The entry {0} {1} in hosts exists. Do you want to remove it?" -f $IPv4Address.IPAddressToString, $DomainName), $Message."Add to hosts", 3,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($Result -eq "Yes") {
        ChangeHostsFile -Network External
        Show-Balloon -TipTitle $Messages."Add to hosts" -TipText ($Messages."Entry {0} {1} removed from hosts." -f $IPv4Address.IPAddressToString, $DomainName)
    }
} else {
    $Result = [System.Windows.Forms.MessageBox]::Show(
        ($Messages."The entry {0} {1} in hosts does not exist. Do you want to add it?" -f $IPv4Address.IPAddressToString, $DomainName), $Message."Add to hosts", 3,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($Result -eq "Yes") {
        ChangeHostsFile -Network Internal
        Show-Balloon -TipTitle $Messages."Add to hosts" -TipText ($Messages."Entry {0} {1} added to hosts." -f $IPv4Address.IPAddressToString, $DomainName)
    }
}