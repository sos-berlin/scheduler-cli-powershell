function Stop-JobSchedulerMaster
{
<#
.SYNOPSIS
Stops a JobScheduler Master or a Master Cluster

.DESCRIPTION
The stop of a Master or Master Cluster can be performed in a graceful manner leaving some time to
running tasks for completion. In addition more immediate operations for aborting
or killing a Master are available and Master instances can be restarted.

.PARAMETER Action
Stopping includes the following actions:

* Action "terminate" (Default)
** no new tasks are started.
** running tasks are continued to complete:
*** shell jobs will continue until their normal termination.
*** API jobs complete a current spooler_process() call.
** JobScheduler Master terminates normally.

* Action "terminate-fail-safe"
** terminates an instance in the same way as -Action "terminate".
** in addition in a Passive Cluster the backup instance will be activated after termination of the primary instance.

* Action "abort"
** no new tasks are started.
** any running tasks are killed.
** JobScheduler Master terminates normally.

* Action "kill"
** the process of the JobScheduler Master is killed including any tasks running.
** no cleanup is performed, e.g. database connections are not closed.
** this action might require elevated privileges of an administrator.
** this operation works on a single Master that is available from a local Master installation and requires prior use of the -UseJobSchedulerMaster cmdlet.

* Action "reactivate"
** performs a fail-back operation in a Master Cluster.
** the currently passive Master becomes active
** the currently active Master is restarted to become a passive cluster member.

.PARAMETER Restart
When used with the operations -Action "terminate" and "abort" then the
JobScheduler Maser instance(s) will shut down and restart.

This switch can be used with the -Cluster switch to restart a JobScheduler Master Cluster.

.PARAMETER Cluster
Carries out the operation -Action "terminate" for a JobScheduler Master Cluster:

* All instances are terminated and optionally are restarted.
* Optional -Timeout settings apply to this operation.

.PARAMETER MasterHost
Should the operation to terminate or to restart a Master not be applied to a standalone Master instance
or to the active Master instance in a cluster, but to a specific Master instance in a cluster
then the respective Master's hostname has to be specified.
Use of this parameter requires to specify the corresponding -MasterPort parameter.

This information is returned by the Get-JobSchedulerStatus cmdlet with the "Cluster" node information.

.PARAMETER MasterPort
Should the operation to terminate or to restart a Master not be applied to a standalone Master instance
or to the active Master instance in a cluster, but to a specific Master instance in a cluster
then the respective Master's port has to be specified.
Use of this parameter requires to specify the corresponding -MasterHost parameter.

This information is returned by the Get-JobSchedulerStatus cmdlet with the "Cluster" node information.

 .PARAMETER Timeout
A timeout is applied for the operation -Action "terminate" that affects running tasks:

* For shell jobs
** in a Unix environment the task is sent a SIGTERM signal and - in case of the timeout parameter being used -
after expiration of the timeout a SIGKILL signal is sent.
** in a Windows environment the task is killed immediately.
* For API jobs
** the method spooler_process() of the respective job will not be called by JobScheduler any more.
** the task is expected to terminate normally after completion of its spooler_process() method.

The timeout is applied when shutting down or restarting (-Restart switch) invidual instances or clustered instances (-Cluster switch).

.PARAMETER Pid
When carrying out the operation -Action "kill" then

* with the PID being specified the given process will be killed
* with no PID being specified the PID is used from the PID file that is created on JobScheduler Master start.

.PARAMETER Service
Stops the JobScheduler Master Windows Service

Use of this parameter ignores any other parameters.
The Windows service is stopped as specified with -Action "terminate".
No timeout and no cluster operations are applied.

.PARAMETER AuditComment
Specifies a free text that indicates the reason for the current intervention, e.g. "business requirement", "maintenance window" etc.

The Audit Comment is visible from the Audit Log view of JOC Cockpit.
This parameter is not mandatory, however, JOC Cockpit can be configured to enforece Audit Log comments for any interventions.

.PARAMETER AuditTimeSpent
Specifies the duration in minutes that the current intervention required.

This information is visible with the Audit Log view. It can be useful when integrated
with a ticket system that logs the time spent on interventions with JobScheduler.

.PARAMETER AuditTicketLink
Specifies a URL to a ticket system that keeps track of any interventions performed for JobScheduler.

This information is visible with the Audit Log view of JOC Cockpit.
It can be useful when integrated with a ticket system that logs interventions with JobScheduler.

.EXAMPLE
Stop-JobSchedulerMaster

Stops a standalone JobScheduler Master instance with normal termination.
This is the same as the operation: Stop-JobSchedulerMaster -Action "terminate"

.EXAMPLE
Stop-JobSchedulerMaster -MasterHost localhost -MasterPort 40444

Stops a JobScheduler Master instance that is a member in a cluster with normal termination.
This is the same as the operation: Stop-JobSchedulerMaster -Action "terminate"

.EXAMPLE
Stop-JobSchedulerMaster -Service

Stops the JobScheduler Master Windows Service with normal termination,
i.e. with -Action "terminate" without any timeouts and cluster options being applied.

.EXAMPLE
Stop-JobSchedulerMaster -Action abort -Restart

Stops a standalone JobScheduler Master instance or the active member of a cluster
by immediately killing any tasks and aborting the JobScheduler Master.
After shutdown the JobScheduler Master instance is restarted.

.EXAMPLE
Stop-JobSchedulerMaster -Action kill -MasterHost localhost -MasterPort 40444

Kills the specific JobScheduler Master instance that is a member in a cluster
and kills any tasks without proper cleanup.

.EXAMPLE
Stop-JobSchedulerMaster -Cluster -Timeout 30

Carries out the -Action "terminate" operation for all members of a JobScheduler Master Cluster.
All running tasks are sent a SIGTERM signal and after expiration of the timeout
any running tasks will be sent a SIGKILL signal.

.EXAMPLE
Stop-JobSchedulerMaster -Restart -Cluster -Timeout 30

Carries out the -Action "terminate" operation for all members of a JobScheduler Master Cluster.
All running tasks are sent a SIGTERM signal and after expiration of the timeout
any running tasks will be sent a SIGKILL signal.

After termination all cluster members will be restarted.

.LINK
about_jobscheduler

#>
[cmdletbinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [ValidateSet('terminate','terminate-fail-safe','abort','kill','reactivate')] [string] $Action = 'terminate',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Restart,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Cluster,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $MasterHost,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $MasterPort = 0,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $Timeout = 0,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [int] $Pid,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Service,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $AuditComment,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $AuditTimeSpent,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $AuditTicketLink
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-JobSchedulerStopWatch

        if ( !$AuditComment -and ( $AuditTimeSpent -or $AuditTicketLink ) )
        {
            throw "$($MyInvocation.MyCommand.Name): Audit Log comment required, use parameter -AuditComment if one of the parameters -AuditTimeSpent or -AuditTicketLink is used"
        }
    }

    Process
    {
        if ( ( $MasterHost -and !$MasterPort ) -or ( !$MasterHost -and $MasterPort ) )
        {
            throw "$($MyInvocation.MyCommand.Name): either both or none of the parameters -MasterHost, -MasterPort have to be specified"
        }

        if ( $Service )
        {
            $serviceInstance = $null
            $serviceName = $script:js.Service.ServiceName

            # Check an existing service
            try
            {
                $serviceInstance = Get-Service $serviceName -ErrorAction SilentlyContinue
            } catch {
                throw "$($MyInvocation.MyCommand.Name): could not find service: $($_.Exception.Message)"
            }

            # stop an existing service
            try
            {
                if ( $serviceInstance -and $serviceInstance.Status -eq "running" )
                {
                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): stop JobScheduler service: $($serviceName)"
                    Stop-Service -Name $serviceName | Out-Null
                    Start-Sleep -s 3
                }
            } catch {
                throw "$($MyInvocation.MyCommand.Name): could not stop service: $($_.Exception.Message)"
            }

            Write-Verbose ".. $($MyInvocation.MyCommand.Name): JobScheduler service stopped: $($serviceName)"
        } else {
            $resource = $null
            $body = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

            switch ( $Action )
            {
                'terminate'
                {
                    if ( $Cluster )
                    {
                        if ( $Restart )
                        {
                            $resource = '/jobscheduler/cluster/restart'
                        } else {
                            $resource = '/jobscheduler/cluster/terminate'
                        }
                    } else {
                        if ( $MasterHost -and $MasterPort )
                        {
                            Add-Member -Membertype NoteProperty -Name 'host' -value $MasterHost -InputObject $body
                            Add-Member -Membertype NoteProperty -Name 'port' -value $MasterPort -InputObject $body
                        }

                        if ( $Restart )
                        {
                            $resource = '/jobscheduler/restart'
                        } else {
                            $resource = '/jobscheduler/terminate'
                        }
                    }

                    if ( $Timeout )
                    {
                        Add-Member -Membertype NoteProperty -Name 'timeout' -value $Timeout -InputObject $body
                    }
                }
                'terminate-fail-safe'
                {
                    $resource = '/jobscheduler/cluster/terminate_failsafe'

                    if ( $Timeout )
                    {
                        Add-Member -Membertype NoteProperty -Name 'timeout' -value $Timeout -InputObject $body
                    }
                }
                'reactivate'
                {
                    $resource = '/jobscheduler/cluster/reactivate'

                    if ( $Timeout )
                    {
                        Add-Member -Membertype NoteProperty -Name 'timeout' -value $Timeout -InputObject $body
                    }
                }
                'abort'
                {
                    if ( $Restart )
                    {
                        $resource = '/jobscheduler/abort_and_restart'
                    } else {
                        $resource = '/jobscheduler/abort'
                    }
                }
                'kill'
                {
                    if ( !$script:js.Install )
                    {
                        throw "$($MyInvocation.MyCommand.Name): kill operation is available for local Master installation only, use -UseJobSchedulerMaster cmdlet"
                    }

                    if ( $Pid )
                    {
                        Write-Verbose ".. $($MyInvocation.MyCommand.Name): killing JobScheduler Master from process list with PID $Pid"
                        $arguments = "-kill=$($Pid)"
                    } else {
                        Write-Verbose ".. $($MyInvocation.MyCommand.Name): killing JobScheduler Master from process list with PID file"
                        $arguments = "-kill -pid-file=$($js.Install.PidFile)"
                    }

                    Write-Debug ".. $($MyInvocation.MyCommand.Name): kill by command: $($arguments)"
                    Start-Process -FilePath "$($js.Install.ExecutableFile)" "$($arguments)" -PassThru | Out-Null
                }
            }

            if ( $resource )
            {
                if ( $AuditComment -or $AuditTimeSpent -or $AuditTicketLink )
                {
                    $objAuditLog = New-Object PSObject
                    Add-Member -Membertype NoteProperty -Name 'comment' -value $AuditComment -InputObject $objAuditLog

                    if ( $AuditTimeSpent )
                    {
                        Add-Member -Membertype NoteProperty -Name 'timeSpent' -value $AuditTimeSpent -InputObject $objAuditLog
                    }

                    if ( $AuditTicketLink )
                    {
                        Add-Member -Membertype NoteProperty -Name 'ticketLink' -value $AuditTicketLink -InputObject $objAuditLog
                    }

                    Add-Member -Membertype NoteProperty -Name 'auditLog' -value $objAuditLog -InputObject $body
                }

                if ( $PSCmdlet.ShouldProcess( $resource ) )
                {
                    [string] $requestBody = $body | ConvertTo-Json -Depth 100
                    $response = Invoke-JobSchedulerWebRequest -Path $resource -Body $requestBody

                    if ( $response.StatusCode -eq 200 )
                    {
                        $requestResult = ( $response.Content | ConvertFrom-JSON )

                        if ( !$requestResult.ok )
                        {
                            throw ( $response | Format-List -Force | Out-String )
                        }

                        Write-Verbose ".. $($MyInvocation.MyCommand.Name): command resource for JobScheduler Master: $resource"
                    } else {
                        throw ( $response | Format-List -Force | Out-String )
                    }
                }
            }
        }
    }

    End
    {
        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
