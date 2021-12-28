
#Requires -module @{ModuleName = 'xActiveDirectory';ModuleVersion = '2.17.0.0'}
#Requires -module @{ModuleName = 'xStorage'; ModuleVersion = '3.4.0.0'}
#Requires -module @{ModuleName = 'xPendingReboot'; ModuleVersion = '0.3.0.0'}

configuration rds {
    Import-DscResource -Module NetworkingDsc
    Import-DscResource -Module ComputerManagementDsc
    Import-DscResource -ModuleName @{ModuleName = 'xPendingReboot'; ModuleVersion = '0.4.0.0' }
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    
    $secdomainpasswd = ConvertTo-SecureString "vagrant" -AsPlainText -Force
    $mydomaincreds = New-Object System.Management.Automation.PSCredential("administrator@contoso.local", $secdomainpasswd)


    Node localhost
    {
        DnsServerAddress DnsServerAddress {
            Address        = '192.168.33.11'
            InterfaceAlias = 'Ethernet'
            AddressFamily  = 'IPv4'
            Validate       = $true
        }

        Computer JoinDomain {
            Name       = $env:computername
            DomainName = "contoso.local"
            Credential = $mydomaincreds
            DependsOn  = '[DnsServerAddress]DnsServerAddress'
        }

        xPendingReboot AfterDomain {
            Name             = 'AfterDomain'
            SkipCcmClientSDK = $true
            DependsOn        = '[Computer]JoinDomain'
        }

        
    }
}



$cd = @{
    AllNodes = @(    
        @{  
            NodeName                    = 'localhost'
            PsDscAllowPlainTextPassword = $true
        }
    ) 
}

rds -ConfigurationData $cd


Start-DscConfiguration -Path rds -verbose -wait -force