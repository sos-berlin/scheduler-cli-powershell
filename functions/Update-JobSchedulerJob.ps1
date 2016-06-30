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
    [ValidateSet('start','wake','stop','unstop','end','suspend','continue')] [string] $Action,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $Parameters,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $At = 'now'
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch

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

        if ( $Action -eq 'start' )
        {
            $jobAttributes = ''
            if ( $At )
            {
                $jobAttributes += " at='$($At)'"
            }
        
            $command += "<start_job job='$($Job)' $jobAttributes>"

            if ( $Parameters )
            {
                $command += '<params>'
                foreach ($p in $Parameters.GetEnumerator()) {
                    $command += "<param name='$($p.Name)' value='$([System.Security.SecurityElement]::Escape($p.Value))'/>"
                }            
                $command += '</params>'
            }
        
            $command += '</start_job>'
        } else {
            $command += "<modify_job job='$($Job)' cmd='$($Action)'/>"
        }
        
        $updateJob = Create-JobObject
        $updateJob.Job = $Job
        $updateJob.At = $At
        $updateJob.Parameters = $Parameters
        $updateJob
        $updateJobCount++
     }

    End
    {
        if ( $updateJobCount )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($updateJobCount) jobs are requested for update"
            $command = "<commands>$($command)</commands>"
            Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to $($js.Url): $command"
        
            $updateXml = Send-JobSchedulerXMLCommand $js.Url $command
        } else {
            Write-Warning "$($MyInvocation.MyCommand.Name): no job found to update"
        }

        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

Set-Alias -Name Update-Job -Value Update-JobSchedulerJob
