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
$tasks = Get-Task

Returns all running and enqueued tasks for all jobs.

.EXAMPLE
$tasks = Get-Task -Directory / -NoSubfolders

Returns all running and enqueued tasks that are configured with the root folder ("live" directory)
without consideration of subfolders.

.EXAMPLE
$tasks = Get-Task -Job /test/globals/job1

Returns all tasks for job "job1" from the folder "/test/globals".

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Job,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $NoRunningTasks,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $NoEnqueuedTasks,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $NoSubfolders,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $UseCache
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch

        $runningTaskNodes = @()
        $runningTaskCount = 0
        $enqueuedTaskNodes = @()
        $enqueuedTaskCount = 0
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

        $xPath = '//folder'

        if ( $Directory )
        {
            if ( $NoSubfolders )
            {
                $xPath += "[@path='$($Directory)']"
            } else {
                $xPath += "[starts-with(@path, '$($Directory)')]"
            }
        }
        
        if ( $Job )
        {
            $xPath += "/jobs/job[@path='$($Job)']"
        } else {
            $xPath += '/jobs/job'
        }

        $xPathRunningTasks = $xPath + '/tasks/task[@task]'
        $xPathEnqueuedTasks = $xPath + '/queued_tasks/queued_task[@task]'
        
        if ( !$UseCache -or !$SCRIPT:jsHasCache )
        {                
            $whatNoSubfolders = if ( $NoSubfolders ) { " no_subfolders" } else { "" }
            $whatTaskQueue = if ( $NoEnqueuedTasks ) { "" } else { " task_queue" }
            $command = "<show_state subsystems='folder job' what='folders$($whatNoSubfolders)$($whatTaskQueue)' path='$($Directory)'/>"
    
            Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Url)"
            Write-Debug ".. $($MyInvocation.MyCommand.Name): sending request: $command"
        
            $taskXml = Send-JobSchedulerXMLCommand $js.Url $command

            if ( !$NoRunningTasks )
            {
                Write-Debug ".. $($MyInvocation.MyCommand.Name): selection for running tasks: $xPathRunningTasks"
                $runningTaskNodes = Select-XML -XML $taskXml -Xpath $xPathRunningTasks
            }

            if ( !$NoEnqueuedTasks )
            {
                Write-Debug ".. $($MyInvocation.MyCommand.Name): selection for enqueued tasks: $xPathEnqueuedTasks"
                $enqueuedTaskNodes = Select-XML -XML $taskXml -Xpath $xPathEnqueuedTasks
            }
        } else {
            if ( !$NoRunningTasks )
            {
                Write-Debug ".. $($MyInvocation.MyCommand.Name): using cache for running tasks: $xPathRunningTasks"
                $runningTaskNodes = Select-XML -XML $SCRIPT:jsStateCache -Xpath $xPathRunningTasks
            }

            if ( !$NoEnqueuedTasks )
            {
                Write-Debug ".. $($MyInvocation.MyCommand.Name): using cache for enqueued tasks: $xPathEnqueuedTasks"
                $enqueuedTaskNodes = Select-XML -XML $SCRIPT:jsStateCache -Xpath $xPathEnqueuedTasks
            }
        }
        
        if ( !$NoRunningTasks )
        {
            foreach( $taskNode in $runningTaskNodes )
            {
                if ( !$taskNode.Node.task )
                {
                    continue
                }
        
                $task = Create-TaskObject
                $task.Task = $taskNode.Node.id
                $task.Job = $taskNode.Node.job
                $task.State = $taskNode.Node.state
                $task.LogFile = $taskNode.Node.log_file
                $task.Steps = $taskNode.Node.steps
                $task.EnqueuedAt = $taskNode.Node.enqueued
                $task.StartAt = $taskNode.Node.start_at
                $task.RunningSince = $taskNode.Node.running_since
                $task.Cause = $taskNode.Node.cause
                $task
                $runningTaskCount++
            }
        }

        if ( !$NoEnqueuedTasks )
        {
            foreach( $taskNode in $enqueuedTaskNodes )
            {
                if ( !$taskNode.Node.task )
                {
                    continue
                }
        
                $task = Create-TaskObject
                $task.Task = $taskNode.Node.id
                $task.Job = ( Select-XML -XML $taskNode.Node -Xpath '../..' ).Node.path
                $task.EnqueuedAt = $taskNode.Node.enqueued
                $task.StartAt = $taskNode.Node.start_at
                $task
                $enqueuedTaskCount++
            }
        }
    }

    End
    {
        if ( $runningTaskCount )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $runningTaskCount running tasks found"
        }
        
        if ( $enqueuedTaskCount )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $enqueuedTaskCount enqueued tasks found"
        }

        if ( !$runningTaskCount -and !$enqueuedTaskCount )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no tasks found"
        }

        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

Set-Alias -Name Get-Task -Value Get-JobSchedulerTask
