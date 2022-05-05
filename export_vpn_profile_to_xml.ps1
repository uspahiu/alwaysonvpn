<#

.SYNOPSIS
    PowerShell script to extract ProfileXML from an existing VPN connection.

.PARAMETER ConnectionName
    The VPN connection name to extract ProfileXML from.

.PARAMETER FileName
    The name of the file to save the extracted ProfileXML.

.PARAMETER AllUserConnection
    Specifies that the VPN connection is deployed for all users.

.PARAMETER DeviceTunnel
    Specifies that the VPN connection is a device tunnel connection.

.EXAMPLE
    .\Get-VPNClientProfileXML.ps1 -ConnectionName 'Always On VPN'

    Running this command will extract the ProfileXML from the VPN connection "Always On VPN" and save the file to the location where the command was executed from.

.EXAMPLE
    .\Get-VPNClientProfileXML.ps1 -ConnectionName 'Always On VPN' -xmlFilePath 'C:\Data\ProfileXML.xml'

    Running this command will extract the ProfileXML from the VPN connection "Always On VPN" and save the file to "C:\Data\ProfileXML.xml"

.EXAMPLE
    .\Get-VPNClientProfileXML.ps1 -ConnectionName 'Always On VPN Device Tunnel' -DeviceTunnel

    Running this command will extract the ProfileXML from the device tunnel VPN connection "Always On VPN Device Tunnel" and save the file to location where the command was executed from.

.DESCRIPTION
    Configuration settings for an Always On VPN connection are stored in ProfileXML. This PowerShell script can be used to view the existing ProfileXML for a given VPN connection in Windows 10. This script is intended for troubleshooting purposes only. The output XML file cannot be used to provision Always On VPN connections using Microsoft Endpoint Manager or PowerShell.

#>

[CmdletBinding()]

Param (

    [Parameter(Mandatory = $True, HelpMessage = "Enter the name of the VPN connection.")]
    [string]$ConnectionName,
    [string]$xmlFilePath = ".\ProfileXML.xml",
    [switch]$AllUserConnection,
    [switch]$DeviceTunnel

)

# // Validate running under the SYSTEM context for device tunnel or all user connection configuration
If ($DeviceTunnel -or $AllUserConnection) {

    # // Script must be running in the context of the SYSTEM account to extract ProfileXML from a device tunnel connection. Validate user, exit if not running as SYSTEM
    $CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

    If ($CurrentPrincipal.Identities.IsSystem -ne $true) {

        Write-Warning 'This script is not running in the SYSTEM context, as required. Exiting script.'
        Exit

    }

    # // Validate VPN connection
    $Vpn = Get-VpnConnection -AllUserConnection -Name $ConnectionName -ErrorAction SilentlyContinue

}

Else {

    # // Validate VPN connection
    $Vpn = Get-VpnConnection -Name $ConnectionName -ErrorAction SilentlyContinue
}

If ($Null -eq $Vpn) {

    Write-Warning "The VPN connection $ConnectionName does not exist. Exiting script."
    Exit

}

# // If file already exists, exit script
If (Test-Path $xmlFilePath) {

    Write-Warning "$xmlFilePath already exists. Exiting script."
    Exit
    
}
Function Format-XML ([xml]$Xml, $Indent = 3) { 

    $StringWriter = New-Object System.IO.StringWriter 
    $XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter 
    $XmlWriter.Formatting = "Indented"
    $XmlWriter.Indentation = $Indent 
    $Xml.WriteContentTo($XmlWriter) 
    $XmlWriter.Flush() 
    $StringWriter.Flush() 
    Write-Output $StringWriter.ToString() 
    
}

# // Remove spaces from VPN connection name
$ConnectionNameEscaped = $ConnectionName -replace ' ', '%20'

# // Extract ProfileXML
Write-Verbose 'Extracting ProfileXML from $ConnectionName...'
$Xml = Get-CimInstance -Namespace 'root\cimv2\mdm\dmmap' -ClassName 'MDM_VPNv2_01' -Filter "ParentID='./Vendor/MSFT/VPNv2' and InstanceID='$ConnectionNameEscaped'" | Select-Object -ExpandProperty ProfileXML

# // Output ProfileXML to file
Write-Verbose "Writing ProfileXML to $xmlFilePath..."
Format-XML $xml | Out-File $xmlFilePath
