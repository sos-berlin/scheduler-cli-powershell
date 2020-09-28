function Start-JobSchedulerJob
{
<#
.SYNOPSIS
Starts jobs in the JobScheduler Master.

.DESCRIPTION
This cmdlet starts standalone jobs with the JobScheduler Master.
Jobs are started independent from the fact if they are stopped
or if they will be started due to calendar events.

.PARAMETER Job
Specifies the full path and name of a job.

.PARAMETER Directory
Optionally specifies the directory of a job should the -Job parameter
not be provided with the full path and name of the job.

.PARAMETER Parameters
Specifies the parameters for the job. Parameters are created from a hashmap,
i.e. a list of names and values.

.PARAMETER At
Specifies the point in time when the job should start:

* now
** specifies that the job should start immediately
* now+1800
** specifies that the job should start with a delay of 1800 seconds, i.e. 30 minutes later.
* yyyy-mm-dd HH:MM[:SS]
** specifies that the job should start at the specified point in time.

.PARAMETER Timezone
Specifies the time zone to be considered for the start time that is indicated with the -At parameter.
Without this parameter the time zone of the JobScheduler Master is assumed. 

This parameter should be used if the JobScheduler Master runs in a time zone different to the environment 
that makes use of this cmdlet.

Find the list of time zone names from https://en.wikipedia.org/wiki/List_of_tz_database_time_zones

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
This cmdlet returns an array of job objects.

.EXAMPLE
Start-JobSchedulerJob -Job /sos/dailyschedule/CheckDaysSchedule

Starts the indicated job.

.EXAMPLE
Start-JobSchedulerJob -Job /sos/dailyschedule/CheckDaysSchedule -At "2038-01-01 00:00:00" -Timezone "Europe/Berlin"

Starts the indicated job for a later date that is specified for the "Europe/Berlin" time zone.

.EXAMPLE
Get-JobSchedulerJob -Directory /some_path -Recursive | Start-JobSchedulerJob

Starts all jobs from the specified directory and sub-folders.

.EXAMPLE
$params = ${ 'par1' = 'val1'; 'par2' = 'val2' }
Start-JobSchedulerJob -Job /some_path/some_job -Parameters $params

Starts the job with parameter 'par1' and 'par2' and respective values.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Job,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $Parameters,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $Environment,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $At,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Timezone,
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
        $stopWatch = Start-StopWatch

        if ( !$AuditComment -and ( $AuditTimeSpent -or $AuditTicketLink ) )
        {
            throw "$($MyInvocation.MyCommand.Name): Audit Log comment required, use parameter -AuditComment if one of the parameters -AuditTimeSpent or -AuditTicketLink is used"
        }

        $objJobs = @()
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
    
        if ( $Job )
        {
            if ( (Get-JobSchedulerObject-Basename $Job) -ne $Job ) # job name includes a directory
            {
                $Directory = Get-JobSchedulerObject-Parent $Job
            } else { # job name includes no directory
                $Job = $Directory + '/' + $Job
            }
        }

        $objJob = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'job' -value $Job -InputObject $objJob

        if ( $At )
        {
            Add-Member -Membertype NoteProperty -Name 'at' -value $At -InputObject $objJob
        }

        if ( $Timezone )
        {
            Add-Member -Membertype NoteProperty -Name 'timeZone' -value $Timezone -InputObject $objJob
        }

        if ( $Parameters )
        {
            Add-Member -Membertype NoteProperty -Name 'params' -value $Parameters -InputObject $objJob
        }

        if ( $Environment )
        {
            Add-Member -Membertype NoteProperty -Name 'environment' -value $Environment -InputObject $objJob
        }

        $objJobs += $objJob    
    }

    End
    {
        if ( $objJobs.count )
        {
            $body = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
            Add-Member -Membertype NoteProperty -Name 'jobs' -value $objJobs -InputObject $body
    
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
            $response = Invoke-JobSchedulerWebRequest '/jobs/start' $requestBody
            
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
        
            $requestResult.tasks
            
            if ( $requestResult.tasks.count -ne $objJobs.count )
            {
                Write-Error "$($MyInvocation.MyCommand.Name): not all tasks could be started, $($objJobs.count) jobs requested, $($requestResult.tasks.count) tasks started"
            }
            
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($requestResult.tasks.count) tasks started"                
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no jobs found"                
        }

        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
