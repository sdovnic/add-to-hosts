# Add to Hosts Script

Hilfsscript zum umgehen eine NAT Loops.

## Konfiguration

Speichern Sie die Datei `add-to-hosts-config-example-xml` als `add-to-hosts-config.xml` ab.

Tragen Sie in der Datei `add-to-hosts-config.xml` Ihre gewünschte IPv4 Adresse und Domainnamen ein.

## Requirements / Vorraussetzungen

* Windows Operating System
* Elevated Command Prompt (Only for the Event Logger / Nur für die Ereignisprotokollierung)

## Supported Operating Systems / Unterstützte Betriebssysteme

* Windows 7
* Windows 8
* Windows 8.1
* Windows 10
* Windows Server 2012
* Windows Server 2012 R2
* Windows Server 2016 Technical Preview

## Installation

Extract the Archive and put the Folder to your desired Location.

Run the Install Scripts depending on what you want to be installed.

If the ExecutionPolicy from PowerShell is Restricted run:

    install.cmd

With PowerShell and configured ExecutionPolicy run:

    add-to-hosts-installer.ps1 install

## Deinstallation

Run the Removal Scripts depending on what you have installed.

If the ExecutionPolicy from PowerShell is Restricted run:

    remove.cmd

With PowerShell and configured ExecutionPolicy run:

    add-to-hosts-installer.ps1 remove
