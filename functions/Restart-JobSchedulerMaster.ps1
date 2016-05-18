function Restart-JobSchedulerMaster
{
<#
.SYNOPSIS
Restarts the JobScheduler Master

.DESCRIPTION
JobScheduler is restarted. Depending on its current operating mode JobScheduler
is restarted in service mode or in dialog mode:

* Service Mode: the Windows service of the JobScheduler Master is restarted.
* Dialog Mode: the JobScheduler Master is restarted in its current user context.

.PARAMETER Action
Restarting includes the following actions:

* Action "terminate" (Default)
** no new tasks are started.
** running tasks are continued to complete:
*** shell jobs will continue until their normal termination.
*** API jobs complete a current spooler_process() call.
** JobScheduler Master terminates normally.

* Action "abort"
** no new tasks are started.
** any running tasks are killed.
** JobScheduler Master terminates normally.

.PARAMETER Cluster
Carries out the operation -Action "terminate" for a JobScheduler Cluster:

* All instances are terminated and restarted.
* Optional -Timeout settings apply to this operation.

.PARAMETER Timeout
A timeout is applied for the operation -Action "terminate" that affects running tasks:

* For shell jobs
** in a Unix environment the task is sent a SIGTERM signal and - in case of the timeout parameter being used - 
after expiration of the timeout a SIGKILL signal is sent.
** in a Windows environment the task is killed immediately.
* For API jobs
** the method spooler_process() of the respective job will not be called by JobScheduler any more. 
** the task is expected to terminate normally after completion of its spooler_process() method.

.PARAMETER Service
Retarts the JobScheduler Windows service.

Without this parameter being specified JobScheduler will be started in 
its respective operating mode, i.e. service mode or dialog mode.

.EXAMPLE
Restart-Master

Restarts the JobScheduler Master.

.EXAMPLE
Restart-Master -Service

Retarts the JobScheduler Master Windows service.

.EXAMPLE
Restart-Master -Cluster -Timeout 20

Retarts the JobScheduler Master Cluster and allows running tasks 20s for completion.

.LINK
about_jobscheduler

#>
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [ValidateSet('terminate','abort')] [string] $Action = "terminate",
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Cluster,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [int] $Timeout,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
	[switch] $Service
)

    Process
    {
		$parameters = @{ "Action"=$Action; "Cluster"=$Cluster; "Timeout"=$Timeout; "Service"=$Service }
		$arguments = New-Object System.Management.Automation.PSObject -Property $parameters
		$arguments | Stop-JobSchedulerMaster -Restart
    }
}

Set-Alias -Name Restart-Master -Value Restart-JobSchedulerMaster
