function Restart-JobSchedulerMaster
{
<#
.SYNOPSIS
Restarts the JobScheduler Master

.DESCRIPTION
JobScheduler Master is restarted. Depending on its current operating mode the Master
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
Restart-JobSchedulerMaster

Terminates and restarts the JobScheduler Master. Any running tasks can complete before 
the Master will restart.

.EXAMPLE
Restart-JobSchedulerMaster -Service

Retarts the JobScheduler Master Windows service.

.EXAMPLE
Restart-JobSchedulerMaster -Cluster -Timeout 20

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
    [int] $Timeout = 0,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
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

        if ( !$AuditComment -and ( $AuditTimeSpent -or $AuditTicketLink ) )
        {
            throw "Audit Log comment required, use parameter -AuditComment if one of the parameters -AuditTimeSpent or -AuditTicketLink is used"
        }        
	}

    Process
    {        
        Stop-JobSchedulerMaster -Action $Action -Cluster:$Cluster -Timeout $Timeout -Service:$Service -Restart -AuditComment $AuditComment -AuditTimeSpent $AuditTimeSpent -AuditTicketLink $AuditTicketLink
    }
}
