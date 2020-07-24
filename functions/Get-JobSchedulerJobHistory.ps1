function Get-JobSchedulerJobHistory
{
<#
.SYNOPSIS
Returns a number of JobScheduler history items for jobs.

.DESCRIPTION
Job history items are returned independently from the fact that the job is present in the JobScheduler Master.

Jobs are selected from a JobScheduler Master

* by the job chain that jobs are used with
* by an individual job
* by any jobs from a directory and optionally any sub-folders

.PARAMETER Job
Specifies the path and name of a job.
If the name of a job is specified then the -Directory parameter is used to determine the folder.
Otherwise the -Job parameter is assumed to include the full path and name of the job.

.PARAMETER JobChain
Optionally specifies the path and name of a job chain that includes jobs.
If the name of a job chain is specified then the -Directory parameter is used to determine the folder.
Otherwise the -JobChain parameter is assumed to include the full path and name of the job chain.

.PARAMETER Directory
Optionally specifies the folder for which jobs should be returned. The directory is determined
from the root folder, i.e. the "live" directory.

.PARAMETER Recursive
Specifies that sub-folders should be looked up if the -Directory parameter is used and no job or job chain is specified.

This operation is time-consuming and should be restricted to selecting individual jobs.

.PARAMETER Compact
Specifies a more compact response with fewer job history attributes.

This operation is time-consuming and should be restricted to selecting individual jobs.

.PARAMETER WithLog
Specifies the task log to be returned. 

This operation is time-consuming and should be restricted to selecting individual jobs.

.PARAMETER MaxLastHistoryItems
Specifies the number of items that are returned from the history. Items are provided
in descending order starting with the latest history item.

Default: 1

.OUTPUTS
This cmdlet returns an array of job history objects.

.EXAMPLE
$history = Get-JobSchedulerJobHistory -JobChain /test/globals/job_chain1

Returns the latest job history item for all jobs used with the job chain "job_chain1" from the "/test/globals" folder.

.EXAMPLE
$history = Get-JobSchedulerJobHistory -JobChain /test/globals/job_chain1 -Job /test/globals/job1

Returns the latest job history item for the specified job that is associated with job chain "job_chain1" from the folder "/test/globals".

.EXAMPLE
$history = Get-JobSchedulerJobHistory -Job /test/globals/job1 -WithLog -MaxLastHistoryItems 5

Returns the latest 5 job history items for job "job1" from the folder "/test/globals" and includes the log output.

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
    [switch] $WithLog,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $MaxLastHistoryItems = 1
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
    }        
        
    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, JobChain=$JobChain Job=$Job"
    
        Get-JobSchedulerJob -Job $Job -JobChain $JobChain -Directory $Directory -Recursive:$Recursive -Compact:$Compact -WithLog:$WithLog -WithHistory -MaxLastHistoryItems $MaxLastHistoryItems    
    }
    
    End
    {
    }
}
