function Stop-JobSchedulerTask
{
<#
.SYNOPSIS
Stops a number of tasks in the JobScheduler Master.

.DESCRIPTION
Stopping tasks includes operations to terminate tasks, e.g. by a SIGTERM signal, and to kill tasks immediately.

Tasks to be stopped are selected

* by a pipelined object, e.g. the output of the Get-JobSchedulerTask cmdlet
* by specifying an individual task with the -Task and -Job parameters.

.PARAMETER Task
Optionally specifies the identifier of a task.

Both parameters -Task and -Job have to be specified if no pipelined task objects are used.

.PARAMETER Job
Optionally specifies the path and name of a job for which tasks should be terminated.

Both parameters -Task and -Job have to be specified if no pipelined task objects are used.

.PARAMETER Action
Specifies the action to be applied to stop a task:

* Action "terminate"
** For shell jobs
*** in a Unix environment the task is sent a SIGTERM signal and - in case of the timeout parameter being used - 
after expiration of the timeout a SIGKILL signal is sent.
*** in a Windows environment the task is killed immediately.
** For API jobs
*** the method spooler_process() of the respective job will not be called by JobScheduler any more. 
*** the task is expected to terminate normally after completion of its spooler_process() method.

* Action "kill"
** tasks are killed immediately.

Default: "kill"

.PARAMETER Timeout
Specifies a timeout to be applied when stopping a task by use of the parameter -Action with the value "terminate".

* For shell jobs
** in Unix environments the task is sent a SIGTERM signal and after expiration of the timeout a SIGKILL signal is sent.
** in Windows environments the timeout is ignored.
* For API jobs
** the method spooler_process() of the respective job will not be called by JobScheduler any more.
** should the job not complete its spooler_process() method within the timeout then the task will be killed.

.INPUTS
This cmdlet accepts pipelined task objects that are e.g. returned from a Get-JobSchedulerTask cmdlet.

.OUTPUTS
This cmdlet returns an array of task objects.

.EXAMPLE
Stop-JobSchedulerTask -Task 81073 -Job /sos/dailyschedule/CheckDaysSchedule

Terminates an individual task.

.EXAMPLE
Get-JobSchedulerTask | Stop-JobSchedulerTask

Terminates all running and enqueued tasks for all jobs.

.EXAMPLE
Get-JobSchedulerTask -Directory / -NoSubfolders | Stop-JobSchedulerTask -Action terminate -Timeout 30

Terminates all running and enqueued tasks that are configured with the root folder ("live" directory)
without consideration of subfolders.

For Unix environments tasks are sent a SIGTERM signal and after expiration of 30s a SIGKILL signal.

.EXAMPLE
Get-JobSchedulerTask -Job /test/globals/job1 | Stop-JobSchedulerTask

Terminates all tasks for job "job1" from the folder "/test/globals".

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Task,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Job,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [ValidateSet("terminate","kill")] [string] $Action = "kill",
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [int] $Timeout = 10
)
	Begin
	{
		Approve-JobSchedulerCommand $MyInvocation.MyCommand

        $killTimeout = ""
        if ( $Action -ne "kill" )
        {
            if ( $Timeout )
            {
                $killTimeout = " timeout='$($Timeout)'"
            } else {
                $killTimeout = " timeout='never'"
            }
        }
    
        $command = ""
        $stopTaskCount = 0
	}

    Process
    {
        if ( !$Job -or !$Task )
        {
            throw "$($MyInvocation.MyCommand.Name): no task and no job specified, use -Task and -Job"
        }

        Write-Verbose ".. $($MyInvocation.MyCommand.Name): stopping task with task='$($task)', job='$($Job)' $killTimeout"

        $command += "<kill_task immediately='yes' job='$($Job)' id='$($Task)' $killTimeout/>"
        $stopTask = Create-TaskObject
        $stopTask.Task = $Task
        $stopTask.Job = $Job
        $stopTask
        $stopTaskCount++
     }

    End
    {
        if ( $stopTaskCount )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($stopTaskCount) tasks are requested to stop"
            $command = "<commands>$($command)</commands>"
            Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to $($js.Url): $command"
        
            $killXml = Send-JobSchedulerXMLCommand $js.Url $command
        } else {
            Write-Warning "$($MyInvocation.MyCommand.Name): no task found to stop"
        }
    }
}
