if ($PSVersionTable.PSVersion.Major -lt 3) {
    [string] $PSScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
}

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

Get-NetIPAddress | ForEach-Object -Process {
    $Pattern = ($IPv4Address.GetAddressBytes()[0..2] -join ".")
    if ($_.IPv4Address -match $Pattern) {
        if (Test-Connection -ComputerName $IPv4Address -ErrorAction SilentlyContinue -Count 1) {
            $Match = $true
        }
    }
}

if ($Match) {
    ChangeHostsFile -Network Internal
} else {
    ChangeHostsFile -Network External
}