function Get-JobSchedulerStatus
{
<#
.SYNOPSIS
Return summary information and statistics information from a JobScheduler Master.

.DESCRIPTION
Summary information and statistics information are returned from a JobScheduler Master.

* Summary information includes e.g. the start date and JobScheduler release.
* Statistics information includes e.g. the number of running tasks and existing orders.

.PARAMETER Statistics
Optionally specifies that detailed statistics information about orders and jobs is returned.

.PARAMETER Display
Optionally specifies formatted output to be displayed.

.PARAMETER NoOutputs
Optionally specifies that no output is returned by this cmdlet.

.EXAMPLE
Get-Status

Returns summary information about the JobScheduler Master.

.EXAMPLE
Get-Status -Statistics -Display

Returns statistics information about jobs, job chains, orders and tasks. Formatted output is displayed.

.EXAMPLE
$status = $Get-Status -Statistics

Returns a status information object including statistics information.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Statistics,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Display,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $NoOutputs
)
	Begin
	{
		Approve-JobSchedulerCommand $MyInvocation.MyCommand
	}

    Process
    {        
        if ( !$Statistics )
        {
            $command = "<show_state what='job_chain_orders' max_task_history='0'/>"
            Write-Debug ". $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Url)"
            Write-Debug ". $($MyInvocation.MyCommand.Name): sending command: $command"
            
            $stateXml = Send-JobSchedulerXMLCommand $js.Url $command    
            if ( $stateXml )
            {
                $state = Create-StatusObject
                $state.Id = $stateXml.spooler.answer.state.id
                $state.Url = $js.Url
				
				if ( !$js.Id ) 
				{
					$SCRIPT:js.Id = $state.Id
				}

                $state.Version = $stateXml.spooler.answer.state.version
                $state.State = $stateXml.spooler.answer.state.state
                $state.Pid = $stateXml.spooler.answer.state.pid
                $state.RunningSince = $stateXml.spooler.answer.state.spooler_running_since
                $state.JobChainsExist = $stateXml.spooler.answer.state.job_chains.count

                $stateXmlState = ( Select-XML -XML $stateXml -Xpath '/spooler/answer/state' ).Node
                $state.OrdersExist = $stateXmlState.CreateNavigator().Evaluate( 'sum(job_chains/job_chain/@orders)' )
                $state.JobsExist = $stateXmlState.CreateNavigator().Evaluate( 'count(jobs/job)' )
                $state.TasksExist = $stateXmlState.CreateNavigator().Evaluate( 'sum(jobs/job/tasks/@count)' )
                $state.TasksEnqueued = $stateXmlState.CreateNavigator().Evaluate( 'sum(jobs/job/queued_tasks/@length)' )

                if ( $Display )
                {
                    $output = "
________________________________________________________________________
Job Scheduler instance: $($state.Id)
.............. version: $($state.Version)
......... operated for: $($state.Url)
........ running since: $($state.RunningSince)
................ state: $($state.State)
.................. pid: $($state.Pid)
........... job chains: $($state.JobChainsExist)
............... orders: $($state.OrdersExist)
................. jobs: $($state.JobsExist)
................ tasks: $($state.TasksExist)
....... enqueued tasks: $($state.TasksEnqueued)
________________________________________________________________________
                    "
                    Write-Host $output
                }

                if ( !$NoOutputs )
                {
                    $state
                }
            }
        }

        if ( $Statistics )
        {
            $command = "<subsystem.show what='statistics'/>"
            Write-Debug ".. sending command to JobScheduler $($js.Url)"
            Write-Debug ".. sending command: $command"
            
            $statXml = Send-JobSchedulerXMLCommand $js.Url $command    
            if ( $statXml )
            {
                $stat = Create-StatisticsObject
                $stat.JobsExist = ( Select-XML -XML $statXml -Xpath "//subsystem[@name = 'job']/file_based.statistics/@count" ).Node."#text"
                $stat.JobsPending = ( Select-XML -XML $statXml -Xpath "//job.statistics/job.statistic[@job_state = 'pending']/@count" ).Node."#text"
                $stat.JobsRunning = ( Select-XML -XML $statXml -Xpath "//job.statistics/job.statistic[@job_state = 'running']/@count" ).Node."#text"
                $stat.JobsStopped = ( Select-XML -XML $statXml -Xpath "//job.statistics/job.statistic[@job_state = 'stopped']/@count" ).Node."#text"
                $stat.JobsNeedProcess = ( Select-XML -XML $statXml -Xpath "//job.statistics/job.statistic[@need_process = 'true']/@count" ).Node."#text"
        
                $stat.TasksExist = ( Select-XML -XML $statXml -Xpath "//task.statistics/task.statistic[@task_state = 'exist']/@count" ).Node."#text"
                $stat.TasksRunning = ( Select-XML -XML $statXml -Xpath "//task.statistics/task.statistic[@task_state = 'running']/@count" ).Node."#text"
                $stat.TasksStarting = ( Select-XML -XML $statXml -Xpath "//task.statistics/task.statistic[@task_state = 'starting']/@count" ).Node."#text"
        
                $stat.OrdersExist = ( Select-XML -XML $statXml -Xpath "//order.statistics/order.statistic[@order_state = 'any']/@count" ).Node."#text"
                $stat.OrdersClustered = ( Select-XML -XML $statXml -Xpath "//order.statistics/order.statistic[@order_state = 'clustered']/@count" ).Node."#text"
                $stat.OrdersStanding = ( Select-XML -XML $statXml -Xpath "//subsystem[@name = 'standing_order']/file_based.statistics/@count" ).Node."#text"
        
                $stat.SchedulesExist = ( Select-XML -XML $statXml -Xpath "//subsystem[@name = 'schedule']/file_based.statistics/@count" ).Node."#text"
                $stat.ProcessClassesExist = ( Select-XML -XML $statXml -Xpath "//subsystem[@name = 'process_class']/file_based.statistics/@count" ).Node."#text"
                $stat.FoldersExist = ( Select-XML -XML $statXml -Xpath "//subsystem[@name = 'folder']/file_based.statistics/@count" ).Node."#text"
                $stat.LocksExist = ( Select-XML -XML $statXml -Xpath "//subsystem[@name = 'lock']/file_based.statistics/@count" ).Node."#text"
                $stat.MonitorsExist = ( Select-XML -XML $statXml -Xpath "//subsystem[@name = 'monitor']/file_based.statistics/@count" ).Node."#text"
                
                if ( $Display )
                {
                    $output = "
________________________________________________________________________
Jobs    
             exist: $($stat.JobsExist)
           pending: $($stat.JobsPending)
           running: $($stat.JobsRunning)
           stopped: $($stat.JobsStopped)
      need process: $($stat.JobsNeedProcess)
Tasks    
             exist: $($stat.TasksExist)
           running: $($stat.TasksRunning)
          starting: $($stat.TasksStarting)
Orders    
             exist: $($stat.OrdersExist)
         clustered: $($stat.OrdersClustered)
          standing: $($stat.OrdersStanding)
Schedules
             exist: $($stat.SchedulesExist)
Process Classes
             exist: $($stat.ProcessClassesExist)
Locks    
             exist: $($stat.LocksExist)
Monitors    
             exist: $($stat.MonitorsExist)
Folders    
             exist: $($stat.FoldersExist)
________________________________________________________________________
                    "
                    Write-Host $output
                }

                if ( !$NoOutputs )
                {
                    $stat
                }
            }
        }
    }
}

Set-Alias -Name Get-Status -Value Get-JobSchedulerStatus
