
<#PSScriptInfo

.VERSION 0.3.1

.GUID edd05043-2acc-48fa-b5b3-dab574621ba1

.AUTHOR Michael Greene

.COMPANYNAME Microsoft Corporation

.COPYRIGHT 

.TAGS DSCConfiguration

.LICENSEURI https://github.com/Microsoft/DomainControllerConfig/blob/master/LICENSE

.PROJECTURI https://github.com/Microsoft/DomainControllerConfig

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
https://github.com/Microsoft/DomainControllerConfig/blob/master/README.md#versions

.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core

#>

#Requires -module @{ModuleName = 'xActiveDirectory';ModuleVersion = '2.17.0.0'}
#Requires -module @{ModuleName = 'xStorage'; ModuleVersion = '3.4.0.0'}
#Requires -module @{ModuleName = 'xPendingReboot'; ModuleVersion = '0.3.0.0'}

<#

.DESCRIPTION 
Demonstrates a minimally viable domain controller configuration script
compatible with Azure Automation Desired State Configuration service.
 
 Required variables in Automation service:
  - Credential to use for AD domain admin
  - Credential to use for Safe Mode recovery

Create these credential assets in Azure Automation,
and set their names in lines 11 and 12 of the configuration script.

Required modules in Automation service:
  - xActiveDirectory
  - xStorage
  - xPendingReboot

#>


configuration DomainControllerConfig
{
    param
    (
        [Parameter(Mandatory = $true)][PSCredential]$domainCredential,
        [Parameter(Mandatory = $true)][PSCredential]$safeModeCredential,
        [Parameter(Mandatory = $true)][string]$domainName
    )

    Import-DscResource -ModuleName @{ModuleName = 'xActiveDirectory'; ModuleVersion = '3.0.0.0' }
    Import-DscResource -ModuleName @{ModuleName = 'xStorage'; ModuleVersion = '3.4.0.0' }
    Import-DscResource -ModuleName @{ModuleName = 'xPendingReboot'; ModuleVersion = '0.4.0.0' }
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

    # When using with Azure Automation, modify these values to match your stored credential names
    #$domainCredential = Get-AutomationPSCredential 'Credential'
    #$safeModeCredential = Get-AutomationPSCredential 'Credential'
  
  
    node localhost
    {
   
	
	
        WindowsFeature ADDSInstall {
            Ensure = 'Present'
            Name   = 'AD-Domain-Services'
        }

        WindowsFeature RSAT-AD-Tools {
 
            Name   = 'RSAT-AD-Tools'
            Ensure = 'Present'
 
        }
 
        WindowsFeature RSAT-ADDS {
 
            Name   = 'RSAT-ADDS'
            Ensure = 'Present'
 
        }

        WindowsFeature RSAT-ADDS-Tools {
 
            Name   = 'RSAT-ADDS-Tools'
            Ensure = 'Present'
 
        }
    
        xPendingReboot BeforeDC {
            Name             = 'BeforeDC'
            SkipCcmClientSDK = $true
            #DependsOn        = '[WindowsFeature]ADDSInstall', '[xDisk]DiskF'
            DependsOn        = '[WindowsFeature]ADDSInstall'
        }
    
        # Configure domain values here
        xADDomain Domain {
            DomainName                    = $domainName
            DomainAdministratorCredential = $domainCredential
            SafemodeAdministratorPassword = $safeModeCredential
            DatabasePath                  = 'C:\NTDS'
            LogPath                       = 'C:\NTDS'
            SysvolPath                    = 'C:\SYSVOL'
            DependsOn                     = '[WindowsFeature]ADDSInstall', '[xPendingReboot]BeforeDC'
        }

        xPendingReboot AfterDC {
            Name             = 'AfterDC'
            SkipCcmClientSDK = $true
            DependsOn        = '[WindowsFeature]ADDSInstall'
        }
    
        Registry DisableRDPNLA {
            Key       = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
            ValueName = 'UserAuthentication'
            ValueData = 0
            ValueType = 'Dword'
            Ensure    = 'Present'
            DependsOn = '[xADDomain]Domain'
        }

        xADUser FirstUser { 
            DomainName = $domainName
            UserName   = "dummy" 
            Password   = $domainCredential 
            Ensure     = "Present" 
            DependsOn  = "[xADDomain]Domain" 
        } 
    }
}

#Install-Module xActiveDirectory,xStorage,xPendingReboot -Confirm:$false -force


$temp_pass = "KT4XaUHmmNXnV3Ff"
$password = ConvertTo-SecureString $temp_pass -AsPlainText -Force
$password_local = ConvertTo-SecureString $temp_pass -AsPlainText -Force

$FirstDomainControllerName = 'localhost'
#$DomainName = "contoso"
#$DomainDnsName = "contoso.local"
 
# We’ll disable the Administrator account; this is the name of the account that will become the new administrator.
#$AdministratorAccount = 'ADifferentUsernameThanAdministrator'
 
#$VMCredentials = Get-Credential -Message "Enter the local administrator credentials." -UserName "vagrant"
$VMCredentials = New-Object System.Management.Automation.PSCredential ('.\myowner', $password_local)

# This is where we’ll type in the password of the new administrator account.

#$DomainAdministratorCredentials = Get-Credential -Message "Enter the domain administrator credentials." -UserName ($DomainName + ‘\’ + $AdministratorAccount)
#$DomainAdministratorCredentials = New-Object System.Management.Automation.PSCredential ($($DomainName + ‘\’ + $AdministratorAccount), $password)

# This is used just to type in the safe mode password; the username isn’t used.

#$SafeModeCredentials = Get-Credential -Message "Enter the new domain's Safe Mode administrator password." -UserName '(Password Only)'
$SafeModeCredentials = New-Object System.Management.Automation.PSCredential ('(Password Only)', $password) 

$cd = @{
    AllNodes = @(    
        @{  
            NodeName                    = $FirstDomainControllerName
            PsDscAllowPlainTextPassword = $true
        }
    ) 
}

DomainControllerConfig -ConfigurationData $cd -safeModeCredential $SafeModeCredentials -domainCredential $VMCredentials -domainName "Contoso.local"

Start-DscConfiguration -Path DomainControllerConfig -verbose -wait -force

 