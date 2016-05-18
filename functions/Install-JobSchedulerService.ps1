function Install-JobSchedulerService
{
<#
.SYNOPSIS
Install the JobScheduler Windows service. This operation requires elevated privileges of a Windows administrator.

.DESCRIPTION
JobScheduler is commonly operated as a Windows service.
The cmdlet installs the service and optionally assigns an account to the service.

.PARAMETER Start
Optionally specifies that the Windows service is started after installation.

.PARAMETER Backup
Specifies that the JobScheduler instance is a backup instance in a passive cluster.

Backup instances use the same JobScheduler ID and database connection as the primary instance.

.PARAMETER Pause
Specifies that the JobScheduler is paused after start-up.

The pause is applied to the initial start-up only, it is not applied
to further starts, e.g. carried out by the Windows service panel.

.PARAMETER PauseAfterFailure
Specifies that the JobScheduler instance will pause on start-up if it has previously been terminated with an error.

This behavior will applies to each start of the Windows service, 
e.g. by use of the Windows service panel.

.PARAMETER UseCredentials
Optionally specifies that credentials are entered for the Windows service. 
Without credentials being specified the JobScheduler Windows service is operated for the system account.

Credentials include to enter the user account and password when being prompted:

* Accounts should include the domain such as in domain\account. For a local account "john" this could be ".\john"
* Passwords are prompted as secure strings.

Alternatively to using this switch the account can be assigned with the Windows service panel.

.EXAMPLE
Install-Service

Removes an existing Windows service and installs the new service.

.EXAMPLE
Install-Service -Start

Installs and starts the Windows service.

.EXAMPLE
Install-Service -Start -Pause

Installs and starts the Windows service.
After star-up the Windows service is paused.

.EXAMPLE
Install-Service -Backup

Installs the Windows service for a JobScheduler backup instance in a passive cluster.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Start,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Backup,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Pause,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $PauseAfterFailure,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $UseCredentials
)
	Begin
	{
		Approve-JobSchedulerCommand $MyInvocation.MyCommand
	}

    Process
    {
        $serviceInstance = $null
        
        $serviceName = $js.Service.ServiceName
        $serviceDisplayName = $js.Service.ServiceDisplayName
        $serviceDescription = $js.Service.ServiceDescription
        
        if ( $Backup )
        {
            $serviceName += '_backup'
            $serviceDisplayName += ' -backup'
        }
        
        # Check an existing service
        try 
        {
            $serviceInstance = Get-Service $serviceName -ErrorAction SilentlyContinue
        } catch {
            # ignore error
            $serviceInstance = $null
        }
        
        # Remove an existing service
        try
        {
            if ( $serviceInstance )
            {
                if ( $serviceInstance.Status -eq "running" -or $serviceInstance.Status -eq "paused" )
                {
                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): stop existing JobScheduler service: $($serviceName)"       
                    $result = Stop-Service -Name $serviceName
                    Start-Sleep -Seconds 3
                }

                Write-Verbose ".. $($MyInvocation.MyCommand.Name): remove existing JobScheduler service: $($serviceName)"       
                $wmiService = Get-WmiObject -Class Win32_Service -Filter "Name='$($serviceName)'"
                $wmiService.Delete()
                Start-Sleep -Seconds 5
            }
        } catch {
            throw "$($MyInvocation.MyCommand.Name): could not remove existing service: $($_.Exception.Message)"
        }
        
        # Install the service

        # "C:\Program Files\sos-berlin.com\jobscheduler\scheduler111\bin\scheduler.exe" -service=sos_scheduler_scheduler111 -id=scheduler111 -sos.ini=C:/ProgramData/sos-berlin.com/jobscheduler/scheduler111/config/sos.ini -config=C:/ProgramData/sos-berlin.com/jobscheduler/scheduler111/config/scheduler.xml -ini=C:/ProgramData/sos-berlin.com/jobscheduler/scheduler111/config/factory.ini -env="SCHEDULER_HOME=C:/Program Files/sos-berlin.com/jobscheduler/scheduler111" -env=SCHEDULER_DATA=C:/ProgramData/sos-berlin.com/jobscheduler/scheduler111 -param=C:/ProgramData/sos-berlin.com/jobscheduler/scheduler111 -cd=C:/ProgramData/sos-berlin.com/jobscheduler/scheduler111 -include-path=C:/ProgramData/sos-berlin.com/jobscheduler/scheduler111 -pid-file=C:/ProgramData/sos-berlin.com/jobscheduler/scheduler111/logs/scheduler.pid
        $serviceBinaryPath = $js.Install.ExecutableFile + " -service=$($serviceName) -id=$($js.Id) -sos.ini=$($js.Config.SosIni) -config=$($js.Config.SchedulerXml) -ini=$($js.Config.FactoryIni) -env=""SCHEDULER_HOME=$($js.Install.Directory)"" -env=""SCHEDULER_DATA=$($js.Config.Directory)"" -param=$($js.Config.Directory) -cd=$($js.Config.Directory) -include-path=$($js.Config.Directory) -pid-file=$($js.Install.PidFile)"

        if ( $PauseAfterFailure )
        {
            $serviceBinaryPath += ' -pause-after-failure'
        }
        
        if ( $UseCredentials )
        {
            $account = Read-Host "Enter user account for JobScheduler service"
            $password = Read-Host "Enter password for JobScheduler service" -AsSecureString
            $credentials = New-Object -typename System.Management.Automation.PSCredential -argumentlist $account, $password
            New-Service -Credential $credentials -BinaryPathName $serviceBinaryPath -Name $serviceName -Description $serviceDescription -DisplayName $serviceDisplayName -StartupType Automatic
        } else {
            New-Service -BinaryPathName $serviceBinaryPath -Name $serviceName -Description $serviceDescription -DisplayName $serviceDisplayName -StartupType Automatic
        }

        # Start the service, optionally in paused mode
        if ( $Start -or $Pause )
        {
            $serviceInstance = Start-Service -Name $serviceName -PassThru
            
            if ( $Pause )
            {
                Start-Sleep -Seconds 3
                $result = $serviceInstance.Pause()
            }
        }
        
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): JobScheduler service installed: $($serviceName)"       
    }
}

Set-Alias -Name Install-Service -Value Install-JobSchedulerService
