function Start-JobSchedulerJob
{
<#
.SYNOPSIS
Starts a number of jobs in the JobScheduler Master.

.DESCRIPTION
This cmdlet is an alias for Update-JobSchedulerJob -Action "start"

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

Default: now

.INPUTS
This cmdlet accepts pipelined job objects that are e.g. returned from a Get-Job cmdlet.

.OUTPUTS
This cmdlet returns an array of job objects.

.EXAMPLE
Start-JobSchedulerJob -Job /sos/dailyschedule/CheckDaysSchedule

Starts an individual job.

.EXAMPLE
Get-JobSchedulerJob -Directory /some_dir -NoSubfolders | Start-JobSchedulerJob

Starts all jobs from the specified directory
without consideration of subfolders.

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
    [string] $AuditComment,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $AuditTimeSpent,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $AuditTicketLink    
)
	Begin
	{
		Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch

        if ( $AuditComment -or $AuditTimeSpent -or $AuditTicketLink )
        {
            if ( !$AuditComment )
            {
                throw "Audit Log comment required, use parameter -AuditComment if one of the parameters -AuditTimeSpent or -AuditTicketLink is used"
            }
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
            Add-Member -Membertype NoteProperty -Name 'timezone' -value $Timezone -InputObject $objJob
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
