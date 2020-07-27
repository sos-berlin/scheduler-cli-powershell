function Stop-JobSchedulerTask
{
<#
.SYNOPSIS
Stops tasks in the JobScheduler Master.

.DESCRIPTION
Stopping tasks includes operations to terminate tasks, e.g. by a SIGTERM signal, and to kill tasks immediately with a SIGKILL signal.

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
Get-JobSchedulerTask -Directory / -Nosub-folders | Stop-JobSchedulerTask -Action terminate -Timeout 30

Terminates all running and enqueued tasks that are configured with the root folder ("live" directory)
without consideration of sub-folders.

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
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Job,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [PSCustomObject[]] $Tasks,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $Timeout = 0,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Kill,
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
            throw "Audit Log comment required, use parameter -AuditComment if one of the parameters -AuditTimeSpent or -AuditTicketLink is used"
        }

        $objJobs = @()
	}

    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Job=$Job, Directory=$Directory"
    
        if ( !$Job -and !$Tasks )
        {
            throw "$($MyInvocation.MyCommand.Name): no job and no tasks specified, use -Job or -Tasks"
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


        $objJob = New-Object PSObject

        if ( $Job )
        {
            Add-Member -Membertype NoteProperty -Name 'job' -value $Job -InputObject $objJob
            
            # if a job is specified then select tasks matching the job path
            if ( $Tasks )
            {
                $taskIds = @()
                foreach( $task in $Tasks )
                {
                    if ( $task.path -and $task.path -eq $Job )
                    {
                        $objTaskId = New-Object PSObject            
                        Add-Member -Membertype NoteProperty -Name 'taskId' -value $task.taskId -InputObject $objTaskId
                        $taskIds += $objTaskId
                    }
                }

                if ( $taskIds.count )
                {
                    Add-Member -Membertype NoteProperty -Name 'taskIds' -value $taskIds -InputObject $objJob
                }
            }
        } elseif ( $Tasks ) {
            foreach( $task in $Tasks )
            {
                $objTaskId = New-Object PSObject            
                Add-Member -Membertype NoteProperty -Name 'taskId' -value $task.taskId -InputObject $objTaskId

                Add-Member -Membertype NoteProperty -Name 'job' -value $task.path -InputObject $objJob
                Add-Member -Membertype NoteProperty -Name 'taskIds' -value @( $objtaskId ) -InputObject $objJob
            }
        }

        if ( $objJob )
        {
            $objJobs += $objJob
        }
     }

    End
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

        if ( $Kill )
        {
            $url = '/tasks/kill'
        } else {
            if ( $Timeout )
            {
                $url = '/tasks/terminate_within'
                Add-Member -Membertype NoteProperty -Name 'timeout' -value $Timeout -InputObject $body
            } else {
                $url = '/tasks/terminate'
            }
        }
        
        if ( $objJobs.count )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($objJobs.count) tasks are requested to stop"        

            [string] $requestBody = $body | ConvertTo-Json -Depth 100
            $response = Invoke-JobSchedulerWebRequest $url $requestBody
            
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
        } else {
            Write-Warning "$($MyInvocation.MyCommand.Name): no tasks found to stop"
        }
        
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch        
    }
}
