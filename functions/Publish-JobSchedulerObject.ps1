function Publish-JobSchedulerObject
{
<#
.SYNOPSIS
Deploys a configuration object such as a job, a job chain etc. to JobScheduler Master.

.DESCRIPTION
This cmdlet deploys a configuration object that is available with JOC Cockpit to the JobScheduler Master.

.PARAMETER Name
Specifies the name of the object, e.g. a job name.

.PARAMETER Directory
Specifies the directory in JOC Cockpit from which the object is available.

.PARAMETER Type
Specifies the object type which is one of:

* JOB
* JOBCHAIN
* ORDER
* PROCESSCLASS
* AGENTCLUSTER
* LOCK
* SCHEDULE
* MONITOR
* NODEPARAMS
* HOLIDAYS

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

.INPUTS
This cmdlet accepts pipelined job objects that are e.g. returned from a Get-Job cmdlet.

.OUTPUTS
This cmdlet returns no output.

.EXAMPLE
Publish-JobSchedulerObject -Name job174 -Directory /some/directory -Type JOB

Deploy the specified job that is available with JOC Cockpit.

.LINK
about_jobscheduler

#>
[cmdletbinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Name,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [ValidateSet('JOB','JOBCHAIN','ORDER','PROCESSCLASS','AGENTCLUSTER','LOCK','SCHEDULE','WORKINGDAYSCALENDAR','NONWORKINGDAYSCALENDAR','FOLDER','JOBSCHEDULER','DOCUMENTATION','MONITOR','NODEPARAMS','HOLIDAYS','JOE','OTHER')]
    [string] $Type,
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
        if ( $Directory -and $Directory -ne '/' )
        {
            if ( $Directory.Substring( 0, 1) -ne '/' ) {
                $Directory = '/' + $Directory
            }

            if ( $Directory.Length -gt 1 -and $Directory.LastIndexOf( '/' )+1 -eq $Directory.Length )
            {
                $Directory = $Directory.Substring( 0, $Directory.Length-1 )
            }
        }

        if ( $Name )
        {
            if ( (Get-JobSchedulerObject-Basename $Name) -ne $Name ) # name includes a directory
            {
                $Directory = Get-JobSchedulerObject-Parent $Name
            } else { # name includes no directory
            }
        }

        if ( $Name )
        {
            $body = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

            if ( $Directory.endsWith('/') )
            {
                Add-Member -Membertype NoteProperty -Name 'path' -value "$($Directory)$($Name)" -InputObject $body
            } else {
                Add-Member -Membertype NoteProperty -Name 'path' -value "$($Directory)/$($Name)" -InputObject $body
            }

            Add-Member -Membertype NoteProperty -Name 'objectType' -value $Type -InputObject $body
            Add-Member -Membertype NoteProperty -Name 'folder' -value $Directory -InputObject $body

            if ( $PSCmdlet.ShouldProcess( '/joe/deploy' ) )
            {
                [string] $requestBody = $body | ConvertTo-Json -Depth 100
                $response = Invoke-JobSchedulerWebRequest -Path '/joe/deploy' -Body $requestBody

                if ( $response.StatusCode -ne 200 )
                {
                    throw ( $response | Format-List -Force | Out-String )
                }

                Write-Verbose ".. $($MyInvocation.MyCommand.Name): object deployed"
            }
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no object deployed"
        }
    }

    End
    {
        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
