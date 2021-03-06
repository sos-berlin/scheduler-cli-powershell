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

.PARAMETER Cluster
Specifies that the JobScheduler instance is a cluster member.

* An active cluster operates a number of instances for shared job execution
* A passive cluster operates a single instance as a primary JobScheduler and any number of additional instances as backup JobSchedulers.

When using -Cluster "passive" then the -Backup parameter can be used to specify that the instance to be installed is a backup JobScheduler.

.PARAMETER Backup
Specifies that the JobScheduler instance is a backup instance in a passive cluster.

Backup instances use the same JobScheduler ID and database connection as the primary instance.

This parameter can only be used with -Cluster "passive".

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
Install-JobSchedulerService

Removes an existing Windows service and installs the new service.

.EXAMPLE
Install-JobSchedulerService -Start

Installs and starts the Windows service.

.EXAMPLE
Install-JobSchedulerService -Start -Pause

Installs and starts the Windows service.
After start-up the Windows service is paused.

.EXAMPLE
Install-JobSchedulerService -Backup

Installs the Windows service for a JobScheduler backup instance in a passive cluster.

.LINK
about_jobscheduler

#>
[cmdletbinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Start,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [ValidateSet("active","passive")] [string] $Cluster,
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
        if ( $Backup -and $Cluster -ne 'passive' )
        {
            throw "$($MyInvocation.MyCommand.Name): Parameter -Backup requires use of a passive cluster, use -Cluster"
        }

        $serviceInstance = $null

        $serviceName = $script:js.Service.ServiceName
        $serviceDisplayName = $script:js.Service.ServiceDisplayName
        $serviceDescription = $script:js.Service.ServiceDescription

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
                    if ( $PSCmdlet.ShouldProcess( 'Master', 'Stop-Seervice' ) )
                    {
                        Stop-Service -Name $serviceName | Out-Null
                    }
                    Start-Sleep -Seconds 3
                }

                Write-Verbose ".. $($MyInvocation.MyCommand.Name): remove existing JobScheduler service: $($serviceName)"
                if ( $PSCmdlet.ShouldProcess( 'Master', 'Remove-CimInstance' ) )
                {
                    # $wmiService = Get-WmiObject -Class Win32_Service -Filter "Name='$($serviceName)'"
                    # $wmiService.Delete()
                    $cimService = Get-CimInstance win32_service -Filter "name='$($serviceName)'"
                    Remove-CimInstance -InputObject $cimService
                    Start-Sleep -Seconds 5
                }
            }
        } catch {
            throw "$($MyInvocation.MyCommand.Name): could not remove existing service: $($_.Exception.Message)"
        }

        # Install the service

        # "C:\Program Files\sos-berlin.com\jobscheduler\scheduler111\bin\scheduler.exe" -service=sos_scheduler_scheduler111 -id=scheduler111 -sos.ini=C:/ProgramData/sos-berlin.com/jobscheduler/scheduler111/config/sos.ini -config=C:/ProgramData/sos-berlin.com/jobscheduler/scheduler111/config/scheduler.xml -ini=C:/ProgramData/sos-berlin.com/jobscheduler/scheduler111/config/factory.ini -env="SCHEDULER_HOME=C:/Program Files/sos-berlin.com/jobscheduler/scheduler111" -env=SCHEDULER_DATA=C:/ProgramData/sos-berlin.com/jobscheduler/scheduler111 -param=C:/ProgramData/sos-berlin.com/jobscheduler/scheduler111 -cd=C:/ProgramData/sos-berlin.com/jobscheduler/scheduler111 -include-path=C:/ProgramData/sos-berlin.com/jobscheduler/scheduler111 -pid-file=C:/ProgramData/sos-berlin.com/jobscheduler/scheduler111/logs/scheduler.pid
        $serviceBinaryPath = $script:js.Install.ExecutableFile + " -service=$($serviceName) -id=$($script:js.Id) -sos.ini=$($script:js.Config.SosIni) -config=$($script:js.Config.SchedulerXml) -ini=$($script:js.Config.FactoryIni) -env=""SCHEDULER_HOME=$($script:js.Install.Directory)"" -env=""SCHEDULER_DATA=$($script:js.Config.Directory)"" -param=$($script:js.Config.Directory) -cd=$($script:js.Config.Directory) -include-path=$($script:js.Config.Directory) -pid-file=$($script:js.Install.PidFile)"

        if ( $Cluster )
        {
            if ( $Cluster -eq 'active' )
            {
                $serviceBinaryPath += ' -distributed-orders'
            } else {
                $serviceBinaryPath += ' -exclusive'
                if ( $Backup )
                {
                    $serviceBinaryPath += ' -backup'
                }
            }
        } elseif ( $script:js.Install.ClusterOptions ) {
            $serviceBinaryPath += " $($script:js.Install.ClusterOptions)"
        }

        if ( $PauseAfterFailure )
        {
            $serviceBinaryPath += ' -pause-after-failure'
        }

        if ( $UseCredentials )
        {
            $account = Read-Host "Enter user account for JobScheduler service"
            $password = Read-Host "Enter password for JobScheduler service" -AsSecureString
            $credentials = New-Object -typename System.Management.Automation.PSCredential -argumentlist $account, $password

            if ( $PSCmdlet.ShouldProcess( 'Master', 'New-Service' ) )
            {
                New-Service -Credential $credentials -BinaryPathName $serviceBinaryPath -Name $serviceName -Description $serviceDescription -DisplayName $serviceDisplayName -StartupType Automatic
            }
        } else {
            if ( $PSCmdlet.ShouldProcess( 'Master', 'New-Service' ) )
            {
                New-Service -BinaryPathName $serviceBinaryPath -Name $serviceName -Description $serviceDescription -DisplayName $serviceDisplayName -StartupType Automatic
            }
        }

        # Start the service, optionally in paused mode
        if ( $Start -or $Pause )
        {
            if ( $PSCmdlet.ShouldProcess( 'Master', 'Start-Service' ) )
            {
                $serviceInstance = Start-Service -Name $serviceName -PassThru

                if ( $Pause )
                {
                    Start-Sleep -Seconds 3
                    $serviceInstance.Pause() | Out-Null
                }
            }
        }

        Write-Verbose ".. $($MyInvocation.MyCommand.Name): JobScheduler service installed: $($serviceName)"
    }
}
