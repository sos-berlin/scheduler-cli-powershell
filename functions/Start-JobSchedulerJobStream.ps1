function Start-JobSchedulerJobStream
{
<#
.SYNOPSIS
Starts job streams in the JobScheduler Master.

.DESCRIPTION
This cmdlet starts job streams with the JobScheduler Master.
Job streams are started by indicated a Starter and optionally start parameters.

.PARAMETER JobStreamStarter
Specifies the full path and name of a job stream starter.

.PARAMETER Directory
Optionally specifies the directory of a job stream should the -JobStreamStarter parameter
not be provided with the full path and name of the job stream.

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
This cmdlet accepts pipelined job objects.

.OUTPUTS
This cmdlet returns an array of job objects.

.EXAMPLE
Start-JobSchedulerJobStream -JobStream /sos/some_starter

Starts the indicated job stream starter.

.EXAMPLE
Start-JobSchedulerJobStream -JobStreamStarter /sos/some_starter

Starts the indicated job stream starter.

.EXAMPLE
Start-JobSchedulerJobStream -JobStreamStarter /some_path/some_starter -Parameters ${ 'par1' = 'val1'; 'par2' = 'val2' }

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

        $objJobStreamStarters = @()
    }

    Process
    {

        $objJobStreamStarter = New-Object PSObject

        if ( $JobStreamStarter )
        {
            Add-Member -Membertype NoteProperty -Name 'title' -value $JobStreamStarter -InputObject $objJobStreamStarter
        }

        $objJobStreamStarters += $objJobStreamStarter
    }

    End
    {
        if ( $objJobStreamStarter.count )
        {
            $body = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
            Add-Member -Membertype NoteProperty -Name 'jobstreamStarters' -value $objJobStreamStarters -InputObject $body

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

            if ( $PSCmdlet.ShouldProcess( $Service, '/jobstreams/start_jobstream' ) )
            {
                [string] $requestBody = $body | ConvertTo-Json -Depth 100
                $response = Invoke-JobSchedulerWebRequest -Path '/jobstreams/start_jobstream' -Body $requestBody

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

                $requestResult.jobStreamStarters

                if ( $requestResult.jobStreamStarters.count -ne $objJobStreamStarters.count )
                {
                    Write-Error "$($MyInvocation.MyCommand.Name): not all job stream starters could be started, $($objJobStreamStarters.count) job stream starters requested, $($requestResult.jobStreamStarters.count) job streams starters started"
                }

                Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($requestResult.jobStreamStarters.count) job stream starters started"
            }
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no job stream starters found"
        }

        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
