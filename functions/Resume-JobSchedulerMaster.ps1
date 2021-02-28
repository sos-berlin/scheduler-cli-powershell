function Resume-JobSchedulerMaster
{
<#
.SYNOPSIS
Continue JobScheduler Master that has previously been paused.
This command is typically executed after a Suspend-JobSchedulerMaster command.

.DESCRIPTION
When JobScheduler Master is continued then

* any task starts that would normally have occurred during the pause period are immediately executed.

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
Resume-JobSchedulerMaster

Continues a previously suspended standalone JobScheduler Master instance or the active Master instance in a cluster.

.EXAMPLE
Resume-JobSchedulerMaster -MasterHost localhost -MasterPort 40444

Continues a previously suspended specific Master instance that could be a member in a cluster.
e.g. the Backup Master instance in a cluster.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $MasterHost,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $MasterPort = 0,
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

        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

        if ( $MasterHost -and $MasterPort )
        {
            Add-Member -Membertype NoteProperty -Name 'host' -value $MasterHost -InputObject $body
            Add-Member -Membertype NoteProperty -Name 'port' -value $MasterPort -InputObject $body
        }

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

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest -Path '/jobscheduler/continue' -Body $requestBody

        if ( $response.StatusCode -eq 200 )
        {
            $requestResult = ( $response.Content | ConvertFrom-JSON )

            if ( !$requestResult.ok )
            {
                throw ( $response | Format-List -Force | Out-String )
            }
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }

        Write-Verbose ".. $($MyInvocation.MyCommand.Name): JobScheduler Master resumed"
    }

    End
    {
        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
