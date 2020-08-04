function Get-JobSchedulerJob
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
    [string] $Job,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Recursive,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Compact,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $WithHistory,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $WithLog,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $MaxLastHistoryItems = 1,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $IsOrderJob,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $IsStandaloneJob,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Pending,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Stopped,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $WaitingForResource,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Running,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Enqueued
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch

        if ( $isOrderJob -and $isStsandaloneJob )
        {
            throw "$($MyInvocation.MyCommand.Name): only one of the parameters -IsOrderJob or -IsStandaloneJob can be specified"
        }
        
        $volatileJobChainJobs = @()
        $returnJobs = @()        
        $states = @()
    }
        
    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, JobChain=$JobChain Job=$Job"
    
        if ( !$Directory -and !$JobChain -and !$Job )
        {
            throw "$($MyInvocation.MyCommand.Name): no directory, job chain or job specified, use -Directory, -JobChain or -Job"
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
    
        if ( $JobChain )
        {
            if ( (Get-JobSchedulerObject-Basename $JobChain) -ne $JobChain ) # job chain name includes a directory
            {
                $Directory = Get-JobSchedulerObject-Parent $JobChain
            } else { # job chain name includes no directory
                if ( $Directory -eq '/' )
                {
                    $JobChain = $Directory + $JobChain
                } else {
                    $JobChain = $Directory + '/' + $JobChain
                }
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
        
        if ( $Directory -eq '/' -and !$JobChain -and !$Job -and !$Recursive )
        {
            $Recursive = $true
        }
        
        if ( $WithLog )
        {
            $WithHistory = $true
        }

        if ( $Pending )
        {
            $states += 'PENDING'
        }

        if ( $Stopped )
        {
            $states += 'STOPPED'
        }

        if ( $WaitingForResource )
        {
            $states += 'WAITINGFORRESOURCE'
        }

        if ( $Running )
        {
            $states += 'RUNNING'
        }

        if ( $Enqueued )
        {
            $states += 'QUEUED'
        }


        if ( $JobChain )
        {
            # JOB CHAIN VOLATILE API
    
            $body = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
            Add-Member -Membertype NoteProperty -Name 'jobChain' -value $JobChain -InputObject $body
    
            [string] $requestBody = $body | ConvertTo-Json -Depth 100
            $response = Invoke-JobSchedulerWebRequest '/job_chain' $requestBody
            
            if ( $response.StatusCode -eq 200 )
            {
                $volatileJobChainJobs = ( $response.Content | ConvertFrom-JSON ).jobchain.nodes
            } else {
                throw ( $response | Format-List -Force | Out-String )
            }
        }
        

        # JOBS VOLATILE API

        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
        
        if ( $Compact )
        {
            Add-Member -Membertype NoteProperty -Name 'compact' -value $true -InputObject $body
        }
        
        if ( !$JobChain -and $Directory )
        {
            $objFolder = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'folder' -value $Directory -InputObject $objFolder
            Add-Member -Membertype NoteProperty -Name 'recursive' -value ($Recursive -eq $true) -InputObject $objFolder

            Add-Member -Membertype NoteProperty -Name 'folders' -value @( $objFolder ) -InputObject $body
        }
        
        if ( $VolatileJobChainJobs )
        {
            $tmpJobs = @()
            foreach( $volatileJobChainJob in $volatileJobChainJobs )
            {
                $objJob = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'job' -value $volatileJobChainJob.job.path -InputObject $objJob
                $tmpJobs += $objJob
            }
            
            Add-Member -Membertype NoteProperty -Name 'jobs' -value $tmpJobs -InputObject $body
        } elseif ( $Job ) {
            $objJob = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'job' -value $Job -InputObject $objJob

            Add-Member -Membertype NoteProperty -Name 'jobs' -value @( $objJob ) -InputObject $body
        }
        
        if ( $IsOrderJob )
        {
            Add-Member -Membertype NoteProperty -Name 'isOrderJob' -value $true -InputObject $body
        } elseif ( $isStandaloneJob ) {
            Add-Member -Membertype NoteProperty -Name 'isOrderJob' -value $false -InputObject $body
        }
        
        if ( $states.count -gt 0 )
        {
            Add-Member -Membertype NoteProperty -Name 'states' -value $states -InputObject $body
        }

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest '/jobs' $requestBody
        
        if ( $response.StatusCode -eq 200 )
        {
            $volatileJobs = ( $response.Content | ConvertFrom-JSON ).jobs
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }

        foreach( $volatileJob in $volatileJobs )
        {
            $returnJob = Create-JobObject
            $returnJob.Job = $volatileJob.name
            $returnJob.Path = $volatileJob.path
            $returnJob.Directory = Get-JobSchedulerObject-Parent $volatileJob.path
            $returnJob.Volatile = $volatileJob
            $returnJob.Tasks = $volatileJob.runningTasks
            
            # additional properties for use with Get-JobSchedulerTask and Stop-JobSchedulerTask
            for ( $i=0; $i -lt $returnJob.Tasks.count; $i++ )
            {
                Add-Member -Membertype NoteProperty -Name 'job' -value $volatileJob.name -InputObject $returnJob.Tasks[$i]
                Add-Member -Membertype NoteProperty -Name 'path' -value $volatileJob.path -InputObject $returnJob.Tasks[$i]
                Add-Member -Membertype NoteProperty -Name 'directory' -value (Get-JobSchedulerObject-Parent $volatileJob.path) -InputObject $returnJob.Tasks[$i]
            }

        
            # JOBS PERMANENT API

            $body = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

            if ( $Compact )
            {
                Add-Member -Membertype NoteProperty -Name 'compact' -value $true -InputObject $body
            }

            $objJob = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'job' -value $volatileJob.path -InputObject $objJob

            Add-Member -Membertype NoteProperty -Name 'jobs' -value @( $objJob ) -InputObject $body

            [string] $requestBody = $body | ConvertTo-Json -Depth 100
            $response = Invoke-JobSchedulerWebRequest '/jobs/p' $requestBody
        
            if ( $response.StatusCode -eq 200 )
            {
                $returnJob.Permanent = ( $response.Content | ConvertFrom-JSON ).jobs
            } else {
                throw ( $response | Format-List -Force | Out-String )
            }

            if ( $WithHistory )
            {
                # JOB HISTORY API
        
                $body = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
                Add-Member -Membertype NoteProperty -Name 'job' -value $volatileJob.path -InputObject $body
                Add-Member -Membertype NoteProperty -Name 'maxLastHistoryItems' -value $MaxLastHistoryItems -InputObject $body

                [string] $requestBody = $body | ConvertTo-Json -Depth 100
                $response = Invoke-JobSchedulerWebRequest '/job/history' $requestBody
        
                if ( $response.StatusCode -eq 200 )
                {
                    $requestHistoryEntries = ( $response.Content | ConvertFrom-JSON ).history
                    $taskHistory = @()                    
                } else {
                    throw ( $response | Format-List -Force | Out-String )
                }

                foreach( $requestHistoryEntry in $requestHistoryEntries )
                {
                    $task = New-Object PSObject
                    Add-Member -Membertype NoteProperty -Name 'history' -value $requestHistoryEntry -InputObject $task

                    if ( $WithLog )
                    {
                        # TASK API

                        $body = New-Object PSObject
                        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
                        Add-Member -Membertype NoteProperty -Name 'taskId' -value $requestHistoryEntry.taskId -InputObject $body

                        [string] $requestBody = $body | ConvertTo-Json -Depth 100
                        $response = Invoke-JobSchedulerWebRequest '/task/log' $requestBody
        
                        if ( $response.StatusCode -eq 200 )
                        {
                            Add-Member -Membertype NoteProperty -Name 'log' -value $response.Content -InputObject $task
                        } else {
                            throw ( $response | Format-List -Force | Out-String )
                        }
                    }
                    
                    $taskHistory += $task
                }

                $returnJob.TaskHistory = $taskHistory
            }
            
            $returnJobs += $returnJob
        }

        $returnJobs
    }
    
    End
    {
        if ( $returnJobs.count )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($returnJobs.count) jobs found"
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no jobs found"
        }
        
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
