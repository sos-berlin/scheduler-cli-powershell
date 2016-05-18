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
    [switch] $NoRunningTasks,
    [switch] $NoEnqueuedTasks,
    [switch] $NoSubfolders
)
    Begin
    {
	}		
		
    Process
    {
		Write-Verbose ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, Job=$Job"
	
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
                if ( $Directory -ne '/' )
                {
                    # Write-Warning "$($MyInvocation.MyCommand.Name): parameter -Directory has been specified, but is replaced by parent folder of -Job parameter"
                }
                $Directory = Get-JobSchedulerObject-Parent $Job
            } else { # job name includes no directory
                $Job = $Directory + '/' + $Job
            }
        }
        
        $whatNoSubfolders = if ( $NoSubfolders ) { " no_subfolders" } else { "" }
        $whatTaskQueue = if ( $NoEnqueuedTasks ) { "" } else { " task_queue" }
        $command = "<show_state subsystems='folder job' what='folders$($whatNoSubfolders)$($whatTaskQueue)' path='$($Directory)'/>"
    
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Hostname):$($js.Port)"
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): sending request: $command"
        
		$taskXml = Send-JobSchedulerXMLCommand $js.Hostname $js.Port $command
        if ( $taskXml )
        {    
            $runningTaskCount = 0
            $enqueuedTaskCount = 0

            if ( !$NoRunningTasks )
            {
				if ( $Job )
				{
					$taskNodes = Select-XML -XML $taskXml -Xpath "//folder/jobs/job[@path='$($Job)']/tasks/task[@task]"
					Write-Verbose ".. $($MyInvocation.MyCommand.Name): selection by job: //folder/jobs/job[@path = '$($Job)']/tasks/task[@task]"
				} else {
					$taskNodes = Select-XML -XML $taskXml -Xpath "//folder/jobs/job/tasks/task[@task]"
					Write-Verbose ".. $($MyInvocation.MyCommand.Name): selection by jobs: //folder/jobs/job/tasks/task[@task]"
				}
                foreach( $taskNode in $taskNodes )
                {
                    if ( !$taskNode.Node.task )
                    {
                        continue
                    }
        
                    $task = Create-TaskObject
                    $task.Id = $taskNode.Node.id
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
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): $runningTaskCount running tasks found"
            }

            if ( !$NoEnqueuedTasks )
            {
                $taskNodes = Select-XML -XML $taskXml -Xpath "//folder/jobs/job/queued_tasks/queued_task[@task]"
                foreach( $taskNode in $taskNodes )
                {
                    if ( !$taskNode.Node.task )
                    {
                        continue
                    }
            
                    $task = Create-TaskObject
                    $task.Id = $taskNode.Node.id
                    $task.Job = ( Select-XML -XML $taskNode.Node -Xpath "../.." ).Node.path
                    $task.EnqueuedAt = $taskNode.Node.enqueued
                    $task.StartAt = $taskNode.Node.start_at
                    $task
                    $enqueuedTaskCount++
                }
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): $enqueuedTaskCount enqueued tasks found"
            }

            if ( !$runningTaskCount -and !$enqueuedTaskCount )
            {
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): no tasks found"
            }
        }
    }
}

# Set-Alias -Name Get-JSTask -Value Get-JobSchedulerTask
Set-Alias -Name Get-Task -Value Get-JobSchedulerTask
