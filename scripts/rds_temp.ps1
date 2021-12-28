$data = @{
    AllNodes = @(
     
        @{
            NodeName                    = '*'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true
     
        },
     
        @{
     
            NodeName = 'gw1.contoso.local'
            Role     = 'Connection Broker'
     
        },
     
        @{
     
            NodeName = 'sh1.contoso.local'
            Role     = 'Session Host'
     
        }
    );
     
    RDSData  = @{
     
        ConnectionBroker             = 'gw1.contoso.local'
        SessionHost                  = 'sh1.contoso.local'
        WebAccessServer              = 'gw1.contoso.local'
        CollectionName               = 'RemoteDesktop'
        AutomaticReconnectionEnabled = $true
        DisconnectedSessionLimitMin  = 60
        IdleSessionLimitMin          = 60
        BrokenConnectionAction       = 'Disconnect'
        UserGroup                    = 'Domain Users'
        LicenseServer                = 'gw1.contoso.local'
        LicenseMode                  = 'PerUser'
        ApplicationName              = "iexplore"
        ApplicationAlias             = "iexplore"
        ApplicationFilePath          = 'C:\Program Files\internet explorer\iexplore.exe'
        ApplicationShowInWebAccess   = $true
    }
}
     
Configuration RDS {
     
    param (
     
        [Parameter(Mandatory = $true)]
        [pscredential]$domainadmin
     
    )
    #region DSC Resource Modules
    #OBS!!! Be sure that the modules exist on the destination host servers
     
    Import-DscResource -ModuleName PSDesiredStateConfiguration,
    @{ModuleName = 'xRemoteDesktopSessionHost'; ModuleVersion = "1.9.0.0" }
     
    #endregion
     
    Node $AllNodes.Where{ $_.Role -eq 'Connection Broker' }.NodeName {
        $RDData = $data.RDSData
     
        
        
        WindowsFeature RDSConnectionBroker {
     
            Name   = 'RDS-Connection-Broker'
            Ensure = 'Present'
        }
     
        WindowsFeature RDLicensing {
            Ensure = "Present"
            Name   = "RDS-Licensing"
        }

        WindowsFeature WebAccess {
     
            Name   = 'RDS-Web-Access'
            Ensure = 'Present'
        }
     
        WaitForAll SessionHost {
     
            NodeName         = 'sh1.contoso.local'
            ResourceName     = '[WindowsFeature]SessionHost'
            RetryIntervalSec = 15
            RetryCount       = 50
            DependsOn        = '[WindowsFeature]RDLicensing'
        }
     
        WaitForAll WebAccess {
     
            NodeName         = 'gw1.contoso.local'
            ResourceName     = '[WindowsFeature]WebAccess'
            RetryIntervalSec = 15
            RetryCount       = 50
            DependsOn        = '[WaitForAll]SessionHost'
        }
        xRDSessionDeployment NewDeployment {
     
            ConnectionBroker     = $RDData.ConnectionBroker
            SessionHost          = $RDData.SessionHost
            WebAccessServer      = $RDData.WebAccessServer
            DependsOn            = '[WaitForAll]WebAccess'
            PsDscRunAsCredential = $domainadmin
        }
        xRDSessionCollection collection {
     
            CollectionName       = $RDData.CollectionName
            SessionHost          = $RDData.SessionHost
            ConnectionBroker     = $RDData.ConnectionBroker
            DependsOn            = '[xRDSessionDeployment]NewDeployment'
            PsDscRunAsCredential = $domainadmin
        }
     
        xRDSessionCollectionConfiguration collectionconfig {
     
            CollectionName               = $RDData.CollectionName
            ConnectionBroker             = $RDData.ConnectionBroker
            AutomaticReconnectionEnabled = $true
            DisconnectedSessionLimitMin  = $RDData.DisconnectedSessionLimitMin
            IdleSessionLimitMin          = $RDData.IdleSessionLimitMin
            BrokenConnectionAction       = $RDData.BrokenConnectionAction
            UserGroup                    = $RDData.UserGroup
            DependsOn                    = '[xRDSessionCollection]collection'
            PsDscRunAsCredential         = $domainadmin
        }

        xRDLicenseConfiguration licenseconfig {
     
            ConnectionBroker     = $RDData.ConnectionBroker
            LicenseServer        = $RDData.LicenseServer
            LicenseMode          = $RDData.LicenseMode
            DependsOn            = '[xRDSessionCollectionConfiguration]collectionconfig'
            PsDscRunAsCredential = $domainadmin
        }
     
    }
     
    Node $AllNodes.Where{ $_.Role -eq 'Session Host' }.NodeName {
     
        WindowsFeature SessionHost {
     
            Name   = 'RDS-RD-Server'
            Ensure = 'Present'
        }

        WindowsFeature telnet {
     
            Name   = 'Telnet-client'
            Ensure = 'Present'
        }
     
    }
}

$secdomainpasswd = ConvertTo-SecureString "vagrant" -AsPlainText -Force
$mydomaincreds = New-Object System.Management.Automation.PSCredential("administrator@contoso.local", $secdomainpasswd)
     
RDS -OutputPath 'C:\DSC Configuration' -domainadmin $mydomaincreds -ConfigurationData $data -Verbose

Start-DscConfiguration -Path 'C:\DSC Configuration' -verbose -wait -force