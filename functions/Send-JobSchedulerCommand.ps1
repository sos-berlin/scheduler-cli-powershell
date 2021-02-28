function Send-JobSchedulerCommand
{
<#
.SYNOPSIS
Sends an XMl command to the JobScheduler Master.

.DESCRIPTION
JobScheduler Master supports a number of XML commands.
This cmdlet accepts XML commands and forwards them to the JobScheduler Master.

.PARAMETER Command
Specifies the XML command to be executed, e.g. <show_state/>

.PARAMETER Headers
A hashmap can be specified with name/value pairs for HTTP headers.

.PARAMETER AuditComment
Specifies a free text that indicates the reason for the current intervention,
e.g. "business requirement", "maintenance window" etc.

The Audit Comment is visible from the Audit Log view of JOC Cockpit.
This parameter is not mandatory, however, JOC Cockpit can be configured
to enforece Audit Log comments for any interventions.

.PARAMETER AuditTimeSpent
Specifies the duration in minutes that the current intervention required.

This information is visible with the Audit Log view. It can be useful when integrated
with a ticket system that logs the time spent on interventions with JobScheduler.

.PARAMETER AuditTicketLink
Specifies a URL to a ticket system that keeps track of any interventions performed for JobScheduler.

This information is visible with the Audit Log view of JOC Cockpit.
It can be useful when integrated with a ticket system that logs interventions with JobScheduler.

.OUTPUTS
This cmdlet returns the XML object of the JobScheduler response.

.EXAMPLE
$stateXml = Send-JobSchedulerCommand '<show_state/>'

Returns summary information and inventory of jobs and job chains.

.EXAMPLE
$stateXml = Send-JobSchedulerCommand '<show_state/>' @{'Accept'='application/xml'}

Returns summary information including the inventory while using individual HTTP headers.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Command,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $Headers = @{'Accept' = 'application/xml'},
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
        Invoke-JobSchedulerWebRequestXmlCommand -Command $Command -Headers $Headers
    }

    End
    {
        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
