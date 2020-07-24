function Get-JobSchedulerTask
{
<#
.SYNOPSIS
Retrieves a number of tasks from the JobScheduler Master.

.DESCRIPTION
Running and enqueued tasks are retrieved from a JobScheduler Master.
Tasks can be selected either by the folder of the job location including subfolders or by an individual job.

Resulting tasks can be forwarded to the Stop-JobSchedulerTask cmdlet in a bulk operation.

.PARAMETER Directory
Optionally specifies the folder with jobs for which tasks should be returned. The directory is determined
from the root folder, i.e. the "live" directory.

One of the parameters -Directory and -Job has to be specified.

.PARAMETER Job
Optionally specifies the path and name of a job for which tasks should be returned.
If the name of a job is specified then the -Directory parameter is used to determine the job folder.
Otherwise the job is assumed to include the full path and name of the job.

One of the parameters -Directory and -Job has to be specified.

.PARAMETER NoRunningTasks
Specifies that no running tasks should be stopped. By default running tasks will be stopped.

.PARAMETER NoEnqueuedTasks
Specifies that no enqueued tasks should be stopped. By default enqueued tasks will be stopped.

.PARAMETER NoSubfolders
Specifies that no subfolders should be looked up for jobs. By default any subfolders will be searched for jobs with tasks.

.PARAMETER UseCache
Specifies that the cache for JobScheduler objects is used. By default the chache is not used
as in most use cases the current information about running tasks is required from the JobScheduler Master.

.OUTPUTS
This cmdlet returns an array of task objects.

.EXAMPLE
$tasks = Get-JobSchedulerTask

Returns all running and enqueued tasks for all jobs.

.EXAMPLE
$tasks = Get-JobSchedulerTask -Directory / -NoSubfolders

Returns all running and enqueued tasks that are configured with the root folder ("live" directory)
without consideration of subfolders.

.EXAMPLE
$tasks = Get-JobSchedulerTask -Job /test/globals/job1

Returns all tasks for job "job1" from the folder "/test/globals".

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Job,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Recursive,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Running,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Enqueued
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch

        $tasks = @()
    }
        
    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, Job=$Job"
    
        if ( !$Directory -and !$Job )
        {
            throw "$($MyInvocation.MyCommand.Name): no directory and no job specified, use -Directory or -Job"
        }

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

        if ( !$Job -and $Directory -eq '/' )
        {
            $Recursive = $true
        }
        
        if ( !$Runnning -and !$Enqueued )
        {
            $Running = $true
        }

        $task = ( Get-JobSchedulerJob -Job $Job -JobChain $JobChain -Directory $Directory -Recursive:$Recursive -Running:$Running -Enqueued:$Enqueued ).Tasks
        
        if ( $task )
        {
            $tasks += $task
        }
    }

    End
    {
        if ( $tasks.count )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($tasks.count) tasks found"
            $tasks
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no tasks found"
        }

        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
