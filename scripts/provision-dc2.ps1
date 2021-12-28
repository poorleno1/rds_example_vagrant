function DisablePassComplexity {
    # Disable password complexity policy
    secedit /export /cfg C:\secpol.cfg
    (get-content C:\secpol.cfg).replace("PasswordComplexity = 1", "PasswordComplexity = 0") | Out-File C:\secpol.cfg
    secedit /configure /db C:\Windows\security\local.sdb /cfg C:\secpol.cfg /areas SECURITYPOLICY
    remove-item -force C:\secpol.cfg -confirm:$false


    # Set administrator password
    $computerName = $env:COMPUTERNAME
    $adminPassword = "vagrant"
    $adminUser = [ADSI] "WinNT://$computerName/Administrator,User"
    $adminUser.SetPassword($adminPassword)

    #$PlainPassword = "vagrant" # "P@ssw0rd"
    #$SecurePassword = $PlainPassword | ConvertTo-SecureString -AsPlainText -Force
}

function LCMConfig {
    Configuration LCMConfig

    {
        Node $env:COMPUTERNAME
        {
            LocalConfigurationManager {
                ConfigurationModeFrequencyMins = 30
                ConfigurationMode              = "ApplyAndAutocorrect"
                RefreshMode                    = "Push"
                RebootNodeIfNeeded             = $true
                ActionAfterReboot              = "ContinueConfiguration"
            }
        }
    }


    # Invoke the DSC  Functions and creat the MOF Files
    LCMConfig -OutputPath "C:\DSCConfigs"



    # Set the Local Config  Manager to use the new MOF for config
    Set-DscLocalConfigurationManager  -Path "C:\DSCConfigs"


    # Apply the file config.
    #Start-DSCConfiguration -Verbose -Wait -Path "C:\DSCConfigs" 
    
    Install-Module xActiveDirectory, xStorage, xPendingReboot -Confirm:$false -force
    install-Module NetworkingDsc -confirm:$false -Force
    #install-Module xDSCDomainjoin -confirm:$false -Force
    install-Module ComputerManagementDsc -confirm:$false -Force
    install-Module xRemoteDesktopSessionHost -confirm:$false -Force
    
    
}


function CreateDomain {
    

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

    DomainControllerConfig -ConfigurationData $cd -safeModeCredential $SafeModeCredentials -domainCredential $VMCredentials -domainName "foo.local"

    Start-DscConfiguration -Path DomainControllerConfig -verbose -wait -force

}



$box = Get-ItemProperty -Path HKLM:SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName -Name "ComputerName"
$box = $box.ComputerName.ToString().ToLower()

if ($env:COMPUTERNAME -imatch 'vagrant') {

    Write-Host 'Hostname is still the original one, skip provisioning for reboot'

    Write-Host 'Install bginfo'
    . c:\vagrant\scripts\install-bginfo.ps1

    Write-Host -fore red 'Hint: vagrant reload' $box '--provision'

}
elseif ((gwmi win32_computersystem).partofdomain -eq $false) {

    Write-Host -fore red "Ooops, workgroup!"

    if ($env:COMPUTERNAME -imatch 'dc2') {
        write-host "Creating domain"
        DisablePassComplexity
        LCMConfig
        CreateDomain
    }
    else {
        Write-Host "Add script that joins to domain."
        #. c:\vagrant\scripts\join-domain.ps1
    }

    Write-Host -fore red 'Hint: vagrant reload' $box '--provision'

}
else {
    Write-Host -fore green "I am domain joined!"
}