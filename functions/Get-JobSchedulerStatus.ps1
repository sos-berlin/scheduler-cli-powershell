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
Specifies that detailed statistics information about orders and jobs is returned.

.PARAMETER Display
Specifies that formatted output will be displayed, otherwise a status object will be returned that contain the respective information.

.EXAMPLE
Get-JobSchedulerStatus

Returns summary information about the JobScheduler Master.

.EXAMPLE
Get-JobSchedulerStatus -Statistics -Display

Returns status information and statistics information about jobs, job chains, orders and tasks. Formatted output is displayed.

.EXAMPLE
$status = $Get-JobSchedulerStatus -Statistics

Returns an object including status information and statistics information.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Statistics,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Display
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-JobSchedulerStopWatch
    }

    Process
    {
        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest '/jobscheduler' $requestBody

        if ( $response.StatusCode -eq 200 )
        {
            $volatileStatus = ( $response.Content | ConvertFrom-JSON ).jobscheduler
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest '/jobscheduler/p' $requestBody

        if ( $response.StatusCode -eq 200 )
        {
            $permanentStatus = ( $response.Content | ConvertFrom-JSON ).jobscheduler
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest '/jobscheduler/cluster/members/p' $requestBody

        if ( $response.StatusCode -eq 200 )
        {
            $clusterStatus = ( $response.Content | ConvertFrom-JSON ).masters
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }

        $returnStatus = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'Volatile' -value $volatileStatus -InputObject $returnStatus
        Add-Member -Membertype NoteProperty -Name 'Permanent' -value $permanentStatus -InputObject $returnStatus
        Add-Member -Membertype NoteProperty -Name 'Cluster' -value $clusterStatus -InputObject $returnStatus


        if ( $Display )
        {
            $output = "
________________________________________________________________________
JobScheduler instance: $($returnStatus.Permanent.jobschedulerId)
............. version: $($returnStatus.Permanent.version)
................. url: $($returnStatus.Permanent.url)
....... running since: $($returnStatus.Permanent.startedAt)
............ timezone: $($returnStatus.Permanent.timezone)
............... state: $($returnStatus.Volatile.state._text)
........ cluster type: $($returnStatus.Permanent.clusterType._type)"

            foreach( $cluster in $returnStatus.cluster )
            {
                $output += "
...... cluster member:   host: $($cluster.host), port: $($cluster.port)
.................. OS:   $($cluster.os.name), $($cluster.os.architecture), $($cluster.os.distribution)"
            }

#            $output += "
#.................. OS: $($returnStatus.Permanent.os.name), $($returnStatus.Permanent.os.architecture), $($returnStatus.Permanent.os.distribution)
#
             $output += "
________________________________________________________________________"
            Write-Output $output
        }

        if ( $Statistics )
        {
            $command = "<subsystem.show what='statistics'/>"
            $statXml = Invoke-JobSchedulerWebRequestXmlCommand -Command $command

            if ( $statXml )
            {
                $stat = New-JobSchedulerStatisticsObject
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
                    Write-Output $output
                }
            }

            Add-Member -Membertype NoteProperty -Name 'Statistics' -value $stat -InputObject $returnStatus
        }

        if ( !$Display )
        {
            $returnStatus
        }
    }

    End
    {
        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
