function Get-JobSchedulerLock
{
<#
.SYNOPSIS
Returns job information from the JobScheduler Master.

.DESCRIPTION
Jobs are returned from a JobScheduler Master. Jobs can be selected by name, folder, status etc. including sub-folders.

The job information retured includes volatile status information and the permanent configuration.
The cmdlet optionally returns the task history and logs of recent task executions.

Resulting jobs can be forwarded to other cmdlets for pipelined bulk operations.

.PARAMETER Job
Optionally specifies the path and name of a job.
If the name of a job is specified then the -Directory parameter is used to determine the folder.
Otherwise the -Job parameter is assumed to include the full path and name of the job.

One of the parameters -Directory, -JobChain or -Job has to be specified.

.PARAMETER JobChain
Optionally specifies the path and name of a job chain that includes jobs.
If the name of a job chain is specified then the -Directory parameter is used to determine the folder.
Otherwise the -JobChain parameter is assumed to include the full path and name of the job chain.

One of the parameters -Directory, -JobChain or -Job has to be specified.

.PARAMETER Directory
Optionally specifies the folder for which jobs should be returned. The directory is determined
from the root folder, i.e. the "live" directory.

.PARAMETER Recursive
Specifies that any sub-folders should be looked up when used with the -Directory parameter.
By default no sub-folders will be looked up for jobs.

.PARAMETER Compact
Specifies that a smaller subset of information is provided, e.g. no task queues for jobs.
By default all information available for jobs is returned.

.PARAMETER WithHistory
Specifies the task history to be returned.
The parameter -MaxLastHstoryitems specifies the number of history items returned.

This operation is time-consuming and should be restricted to selecting individual jobs.

.PARAMETER WithLog
Specifies the task log to be returned. This implicitely includes to return the task history.
For each history item - up to the number speicifed with the -MaxLastHistoryItems parameter -
the task log is returned.

This operation can be time-consuming.

.PARAMETER MaxLastHistoryItems
Specifies the number of the most recent history items of task executions to be returned.

Default: 1

.PARAMETER IsOrderJob
Specifies to exclusively return jobs that can be used in job chains.

.PARAMETER IsStandaloneJob
Specifies to exclucively return jobs that can be used standalone (without job chains).

.PARAMETER Pending
Returns jobs in a pending state, i.e. jobs that are ready to be executed at a later date.

.PARAMETER Stopped
Returns stopped jobs. Such jobs would not restart automatically.

.PARAMETER Running
Specifies that jobs with running tasks should be returned.

.PARAMETER Enqueued
Specifies that jobs with enqueued tasks should be returned.

.OUTPUTS
This cmdlet returns an array of job objects.

.EXAMPLE
$jobs = Get-JobSchedulerJob

Returns all jobs from all directories recursively.

.EXAMPLE
$jobs = Get-JobSchedulerJob -Directory /test

Returns all jobs that are configured with the folder "test"
without consideration of sub-folders.

.EXAMPLE
$jobs = Get-JobSchedulerJob -Directory /test -Recursive

Returns all jobs that are configured with the folder "test"
include jobs from any sub-folders.

.EXAMPLE
$jobs = Get-JobSchedulerJob -JobChain /test/globals/job_chain1

Returns the jobs that are associated with the job chain "job_chain1" from the folder "/test/globals".

.EXAMPLE
$jobs = Get-JobSchedulerJob -Job /test/globals/job1

Returns the job "job1" from the folder "/test/globals".

.EXAMPLE
$jobs = Get-JobSchedulerJob -Stopped

Returns any stopped jobs.

.EXAMPLE
$jobs = Get-JobSchedulerJob -Directory /test -Pending -Running

Returns any pending or running jobs from the "/test" directory.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Lock,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Recursive
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-JobSchedulerStopWatch

        $locks = @()
        $folders = @()
    }

    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, Recursive=$Recursive, Lock=$Lock"

        if ( !$Directory -and !$Lock )
        {
            throw "$($MyInvocation.MyCommand.Name): no directory or lock specified, use -Directory or -Lock"
        }

        if ( $Directory -and $Directory -ne '/' )
        {
            if ( !$Directory.startsWith( '/' ) ) {
                $Directory = '/' + $Directory
            }

            if ( $Directory.endsWith( '/' ) )
            {
                $Directory = $Directory.Substring( 0, $Directory.Length-1 )
            }
        }

        if ( $Lock )
        {
            if ( (Get-JobSchedulerObject-Basename $Lock) -ne $Lock ) # lock name includes a directory
            {
                $Directory = Get-JobSchedulerObject-Parent $Lock
            } else { # lock name includes no directory
                if ( $Directory -eq '/' )
                {
                    $Lock = $Directory + $Lock
                } else {
                    $Lock = $Directory + '/' + $Lock
                }
            }
        }

        if ( $Directory -eq '/' -and !$Lock -and !$Recursive )
        {
            $Recursive = $true
        }

        if ( $Lock )
        {
            $locks += $Lock
        }

        if ( $Directory )
        {
            $objFolder = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'folder' -value $Directory -InputObject $objFolder
            Add-Member -Membertype NoteProperty -Name 'recursive' -value ($Recursive -eq $true) -InputObject $objFolder

            $folders += $objFolder
        }
    }

    End
    {
        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

        if ( $locks )
        {
            Add-Member -Membertype NoteProperty -Name 'locks' -value $locks -InputObject $body
        }

        if ( $folders )
        {
            Add-Member -Membertype NoteProperty -Name 'folders' -value $folders -InputObject $body
        }

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest -Path '/locks/p' -Body $requestBody

        if ( $response.StatusCode -eq 200 )
        {
            $returnLocks = ( $response.Content | ConvertFrom-Json ).locks
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }

        $returnLocks | Select-Object -Property `
                                            name, `
                                            @{name='lock'; expression={ $_.path }}, `
                                            path, `
                                            maxNonExclusive, `
                                            configurationDate, `
                                            surveyDate

        if ( $returnLocks.count )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($returnLocks.count) locks found"
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no locks found"
        }

        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
