function Start-JobSchedulerMaster
{
<#
.SYNOPSIS
Starts the JobScheduler Master from a local Windows installation.

.DESCRIPTION
JobScheduler can be started in service mode and in dialog mode:

* Service Mode: the Windows service of the JobScheduler Master is started.
* Dialog Mode: the JobScheduler Master is started in the context of the current user account.

.PARAMETER Service
Starts the JobScheduler Windows service.

Without this parameter being specified JobScheduler will be started in dialog mode.

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

When used with -Service then the pause is applied to the initial start-up only, it is not applied
to further starts, e.g. carried out by the Windows service panel.

.PARAMETER PauseAfterFailure
Specifies that the JobScheduler Master will pause on start-up if it has previously been terminated with an error.

When used with -Service then this behavior will apply to each start of the Windows service,
e.g. by use of the Windows service panel.

.EXAMPLE
Start-JobSchedulerMaster

Starts the JobScheduler Master in dialog mode.

.EXAMPLE
Start-JobSchedulerMaster -Service

Starts the JobScheduler Master Windows service.

.LINK
about_jobscheduler

#>
[cmdletbinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Service,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [ValidateSet('active','passive')] [string] $Cluster,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Backup,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Pause,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $PauseAfterFailure
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-JobSchedulerStopWatch

        if ( !$isWindows )
        {
            throw "$($MyInvocation.MyCommand.Name): cmdlet can be used with Windows OS only"
        }
    }

    Process
    {
        if ( $Backup -and $Cluster -ne 'passive' )
        {
            throw "$($MyInvocation.MyCommand.Name): Parameter -Backup requires use of a passive cluster, use -Cluster"
        }

        if ( $Service )
        {
            if ( $Cluster )
            {
                throw "$($MyInvocation.MyCommand.Name): parameters -Service and -Cluster not compatible, use Install-JobSchedulerService cmdlet to run the service with -Cluster"
            }

            if ( $PauseAfterFailure )
            {
                throw "$($MyInvocation.MyCommand.Name): parameters -Service and -PauseAfterFailure not compatible, use Install-JobSchedulerService cmdlet to run the service with -PauseAfterFailure"
            }

            Write-Verbose ".. $($MyInvocation.MyCommand.Name): starting JobScheduler service with ID '$($script:js.Id)' at '$($script:js.Url)'"
            if ( $PSCmdlet.ShouldProcess( 'Master' ) )
            {
                $serviceInstance = Start-Service -Name $script:js.Service.serviceName -PassThru
            }

            if ( $Pause )
            {
                Start-Sleep -Seconds 3
                if ( $PSCmdlet.ShouldProcess( 'Master' ) )
                {
                    $serviceInstance.Pause() | Out-Null
                }
            }
        } else {
            $startOptions = ''

            if ( $Cluster )
            {
                if ( $Cluster -eq 'active' )
                {
                    $startOptions += ' -distributed-orders'
                } else {
                    $startOptions += ' -exclusive'
                    if ( $Backup )
                    {
                        $startOptions += ' -backup'
                    }
                }
            } elseif ( $script:js.Install.ClusterOptions ) {
                $startOptions += " $($script:js.Install.ClusterOptions)"
            }

            if ( $PauseAfterFailure )
            {
                $startOptions += ' -pause-after-failure'
            }

            $command = """$($script:js.Install.ExecutableFile)"" $($script:js.Install.StartParams)$($startOptions)"
            Write-Debug ".. $($MyInvocation.MyCommand.Name): start by command: $command"
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): starting JobScheduler instance with ID '$($script:js.Id)' at '$($script:js.Url)'"
            if ( $PSCmdlet.ShouldProcess( 'Master', 'Start-Process' ) )
            {
                Start-Process -FilePath "$($script:js.Install.ExecutableFile)" "$($script:js.Install.StartParams)$($startOptions)" -PassThru | Out-Null
            }

            if ( $Pause )
            {
                Start-Sleep -Seconds 3
                $command = "<modify_spooler cmd='pause'/>"

                Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($script:js.Url)"
                Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command: $command"

                if ( $PSCmdlet.ShouldProcess( $command, 'Invoke-JobSchedulerWebRequestXmlCommand' ) )
                {
                    Invoke-JobSchedulerWebRequestXmlCommand -Command $command -Headers @{'Accept' = 'application/xml'}
                }
            }
        }
    }

    End
    {
        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
