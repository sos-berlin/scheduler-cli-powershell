function Start-JobSchedulerJobStream
{
<#
.SYNOPSIS
Starts job streams with the JobScheduler Master.

.DESCRIPTION
This cmdlet starts job streams with the JobScheduler Master.
Job streams are started by indicated a Starter and optionally start parameters.

.PARAMETER JobStreamStarter
Specifies the full path and name of a job stream starter.

.PARAMETER Parameters
Specifies the parameters for the job stream. Parameters are created from a hashmap,
i.e. a list of names and values.

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
This cmdlet accepts pipelined job sream starter names.

.OUTPUTS
This cmdlet returns an array of items indicating the job stream start including parameters, session ID etc.

.EXAMPLE
$jsStart = Start-JobSchedulerJobStream -JobStreamStarter some_starter

Starts the indicated job stream starter.

.EXAMPLE
$jsStart = Start-JobSchedulerJobStream -JobStreamStarter some_starter -Parameters @{ 'par1' = 'val1'; 'par2' = 'val2' }

Starts the job stream starter with parameters 'par1', 'par2' and respective values.

.LINK
about_jobscheduler

#>
[cmdletbinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobStreamStarter,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $Parameters,
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

        $jobStreamStarters = @()
    }

    Process
    {
        $objJobStreamStarter = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'starterName' -value $JobStreamStarter -InputObject $objJobStreamStarter

        if ( $Parameters )
        {
            $objParameters = @()
            $Parameters.GetEnumerator() | Foreach-Object {
                $objParameter = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'name' -value $_.name -InputObject $objParameter
                Add-Member -Membertype NoteProperty -Name 'value' -value $_.value -InputObject $objParameter
                $objParameters += $objParameter
            }
            Add-Member -Membertype NoteProperty -Name 'params' -value $objParameters -InputObject $objJobStreamStarter
        }

        $jobStreamStarters += $objJobStreamStarter
    }

    End
    {
        if ( $jobStreamStarters.count )
        {
            $body = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
            Add-Member -Membertype NoteProperty -Name 'jobstreamStarters' -value $jobStreamStarters -InputObject $body

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

            if ( $PSCmdlet.ShouldProcess( $Service, '/jobstreams/start' ) )
            {
                [string] $requestBody = $body | ConvertTo-Json -Depth 100
                $response = Invoke-JobSchedulerWebRequest -Path '/jobstreams/start' -Body $requestBody

                if ( $response.StatusCode -eq 200 )
                {
                    $requestResult = ( $response.Content | ConvertFrom-Json )

                    if ( !$requestResult.jobSchedulerId )
                    {
                        throw ( $response | Format-List -Force | Out-String )
                    }
                } else {
                    throw ( $response | Format-List -Force | Out-String )
                }

                $requestResult

                if ( $jobStreamStarters.count )
                {
                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($requestResult.jobStreamStarters.count) job stream starters started"
                } else {
                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): no job stream starters specified"
                }
            }
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no job stream starters specified"
        }

        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
