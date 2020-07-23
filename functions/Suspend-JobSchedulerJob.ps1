function Suspend-JobSchedulerJob
{
<#
.SYNOPSIS
Stops a number of jobs in the JobScheduler Master.

.DESCRIPTION
This cmdlet is an alias for Update-JobSchedulerJob -Action "stop"

.PARAMETER Job
Specifies the full path and name of a job.

.PARAMETER Directory
Optionally specifies the directory of a job should the -Job parameter
not be provided with the full path and name of the job.

.INPUTS
This cmdlet accepts pipelined job objects that are e.g. returned from a Get-Job cmdlet.

.OUTPUTS
This cmdlet returns an array of job objects.

.EXAMPLE
Stop-JobSchedulerJob -Job /sos/dailyschedule/CheckDaysSchedule

Stops an individual job.

.EXAMPLE
Get-JobSchedulerJob -Directory /some_dir -NoSubfolders | Stop-JobSchedulerJob

Stops all jobs from the specified directory 
without consideration of subfolders.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Job,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
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
				if ( $Directory -eq '/' )
				{
					$Job = $Directory + $Job
				} else {
					$Job = $Directory + '/' + $Job
				}
            }
        }
    
        $objJob = New-Object PSObject

        if ( $Job )
        {
            Add-Member -Membertype NoteProperty -Name 'job' -value $Job -InputObject $objJob
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
            $response = Invoke-JobSchedulerWebRequest '/jobs/stop' $requestBody
            
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
        
            $objJobs
            
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($objJobs.count) jobs suspended"                
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no jobs found"                
        }

        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
