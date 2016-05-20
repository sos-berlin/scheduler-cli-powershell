function Start-JobSchedulerJob
{
<#
.SYNOPSIS
Starts a number of jobs in the JobScheduler Master.

.DESCRIPTION
This cmdlet is an alias for Update-Job -Action "start"

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

.INPUTS
This cmdlet accepts pipelined job objects that are e.g. returned from a Get-Job cmdlet.

.OUTPUTS
This cmdlet returns an array of job objects.

.EXAMPLE
Start-Job -Job /sos/dailyschedule/CheckDaysSchedule

Starts an individual job.

.EXAMPLE
Get-Job -Directory /some_dir -NoSubfolders | Start-Job

Starts all jobs from the specified directory
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
    [hashtable] $Parameters,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $At = 'now'
)
	Begin
	{
		Approve-JobSchedulerCommand $MyInvocation.MyCommand

        $startJobs = @()
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
    
        $j = Create-JobObject
        $j.Job = $Job
        $j.Path = $Job
        $j.Directory = Get-JobSchedulerObject-Parent $Job
		$j.At = $At
		$j.Parameters = $Parameters
        $startJobs += $j
    }

    End
    {
        $startJobs | Update-JobSchedulerJob -Action start
    }
}

Set-Alias -Name Start-Job -Value Start-JobSchedulerJob
