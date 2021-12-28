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
