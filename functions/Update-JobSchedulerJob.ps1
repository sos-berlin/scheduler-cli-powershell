function Update-JobSchedulerJob
{
<#
.SYNOPSIS
Updates a number of jobs in the JobScheduler Master.

.DESCRIPTION
Updating jobs includes operations to stop and unstop jobs.

Jobs to be stopped are selected

* by a pipelined object, e.g. the output of the Get-Job cmdlet
* by specifying an individual job with the -Job parameter.

.PARAMETER Job
Specifies the path and name of a job that should be updated.

.PARAMETER Action
Specifies the action to be applied to stop a task:

* Action "stop"
** jobs are stopped immediately. Any running tasks are continued to completion.
** a stopped job does not execute any tasks. Orders in a job chain wait for stopped jobs to be resumed.

* Action "unstop"
** unstops a previously stopped job.

.INPUTS
This cmdlet accepts pipelined job objects that are e.g. returned from a Get-Job cmdlet.

.OUTPUTS
This cmdlet returns an array of job objects.

.EXAMPLE
Update-Job -Job /sos/dailyschedule/CheckDaysSchedule -Action stop

Stops an individual job.

.EXAMPLE
Get-Job | Update-Job -Action unstop

Unstops all jobs that have previously been stopped.

.EXAMPLE
Get-Job -Directory /some_dir -NoSubfolders | Update-Job -Action stop

Stops all jobs from the specified directory 
without consideration of subfolders.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Job,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [ValidateSet('start','wake','stop','unstop','end','suspend','continue')] [string] $Action
)
    Begin
    {
        $command = ""
        $updatedJobCount = 0
	}

    Process
    {
        if ( !$Job )
        {
            throw "$($MyInvocation.MyCommand.Name): no job specified, use -Job"
        }

        Write-Verbose ".. $($MyInvocation.MyCommand.Name): updating job='$($Job)' action='$($Action)'"

        $command += "<modify_job job='$($Job)' cmd='$($Action)'/>"
        $updateJob = Create-JobObject
        $updateJob.Job = $Job
        $updateJob
        $updateJobCount++
     }

    End
    {
        if ( $updateJobCount )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($updateJobCount) jobs are requested for update"
            $command = "<commands>$($command)</commands>"
            Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to $($js.Hostname):$($js.Port): $command"
        
            $updateXml = Send-JobSchedulerXMLCommand $js.Hostname $js.Port $command
        } else {
            Write-Warning "$($MyInvocation.MyCommand.Name): no job found to update"
        }
    }
}

Set-Alias -Name Update-Job -Value Update-JobSchedulerJob
