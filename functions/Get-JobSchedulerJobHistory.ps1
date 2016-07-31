function Get-JobSchedulerJobHistory
{
<#
.SYNOPSIS
Returns a number of JobScheduler history entries for jobs.

.DESCRIPTION
Job history entries are returned independently from the fact that the job is present in the JobScheduler Master.

Jobs are selected from a JobScheduler Master

* by the job chain that jobs are assigned to
* by an individual job.

.PARAMETER Directory
Optionally specifies the folder for which jobs should be returned. The directory is determined
from the root folder, i.e. the "live" directory.

.PARAMETER JobChain
Optionally specifies the path and name of a job chain that includes jobs.
If the name of a job chain is specified then the -Directory parameter is used to determine the folder.
Otherwise the -JobChain parameter is assumed to include the full path and name of the job chain.

.PARAMETER Job
Specifies the path and name of a job.
If the name of a job is specified then the -Directory parameter is used to determine the folder.
Otherwise the -Job parameter is assumed to include the full path and name of the job.

.PARAMETER MaxHistoryEntries
Specifies the number of entries that are returned from the history. Entries are provided
in descending order starting with the latest history entry.

Default: 1

.PARAMETER WithLog
Specifies the task log to be returned. 

This operation is time-consuming and should be restricted to selecting individual jobs.

.OUTPUTS
This cmdlet returns an array of job history objects.

.EXAMPLE
$history = Get-JobSchedulerJobHistory -JobChain /test/globals/job_chain1 -Job /test/globals/job1

Returns the latest job history entry for the specified job that is associated with job chain "job_chain1" from the folder "/test/globals".

.EXAMPLE
$history = Get-JobSchedulerJobHistory -Job /test/globals/job1 -MaxHistoryEntries 5

Returns the latest 5 job history entries for job "job1" from the folder "/test/globals" and includes the log output.

.EXAMPLE
$history = Get-JobSchedulerJobHistory -Job /test/globals/job1 -MaxHistoryEntries -WithLog

Returns the latest 5 job history entries for job "job1" from the folder "/test/globals" and includes the log output.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Job,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $MaxHistoryEntries = 1,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $WithLog
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch

        $jobHistoryCount = 0        
    }        
        
    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, JobChain=$JobChain Job=$Job"
    
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

        if ( $WithLog )
        {
            $whatWithLog = ' log'
        } else {
            $whatWithLog = ''
        }
        
        if ( $JobChain )
        {
            $command = "<show_job job_chain='$($JobChain)' job='$($Job)' max_task_history='$($MaxHistoryEntries)' what='task_history$($whatWithLog)'/>"
        } else {
            $command = "<show_job job='$($Job)' max_task_history='$($MaxHistoryEntries)' what='task_history$($whatWithLog)'/>"
        }

        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Url)"
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending request: $command"

        $jobXml = Send-JobSchedulerXMLCommand $js.Url $command

        $xPath = '/spooler/answer/job'
        Write-Debug ".. $($MyInvocation.MyCommand.Name): using XPath: $($xPath)"
        $jobNodes = Select-XML -XML $jobXml -Xpath $xPath

        if ( $jobNodes )
        {    
            foreach( $jobNode in $jobNodes )
            {        
                $j = Create-JobHistoryObject

                if ( !$jobNode.Node.name )
                {
                    continue
                }
                $j.Job = $jobNode.Node."name"
                $j.Path = $jobNode.Node.path
                $j.Directory = Get-JobSchedulerObject-Parent $jobNode.Node.path                

                $j.State = $jobNode.Node.state
                $j.Title = $jobNode.Node.title
                $j.LogFile = $jobNode.Node.log_file
                $j.Tasks = $jobNode.Node.tasks
                $j.IsOrder =  ( $jobNode.Node.order -eq 'yes' )
                $j.ProcessClass = $jobNode.Node.process_class
                $j.NextStartTime = $jobNode.Node.next_start_time
                $j.StateText = $jobNode.Node.state_text

                foreach( $historyNode in $jobNode.Node."history"."history.entry" )
                {
                    $j.AgentUrl = $historyNode.agent_url
                    $j.Cause = $historyNode.cause
                    $j.StartTime = $historyNode.start_time
                    $j.EndTime = $historyNode.end_time
                    $j.ExitCode = $historyNode.exit_code
                    $j.Task = $historyNode.task
                    $j.Steps = $historyNode.steps
                    
                    if ( $WithLog )
                    {
                        $j.Log = $historyNode.log
                    }

                    $j
                    $jobHistoryCount++
                }
                
            }
        }
    }
    
    End
    {
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): $jobHistoryCount job history entries found"
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
