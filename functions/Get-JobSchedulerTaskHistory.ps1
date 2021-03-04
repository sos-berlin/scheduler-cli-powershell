function Get-JobSchedulerTaskHistory
{
<#
.SYNOPSIS
Returns the task execution history for jobs.

.DESCRIPTION
History information is returned for jobs from a JobScheduler Master.
Task executions can be selected by job name, folder, history status etc.

The history information retured includes start time, end time, return code etc.

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

.PARAMETER OrderId
Optionally specifies the identifier of an order to limit results to jobs that
correspond to the order's current state.

.PARAMETER Directory
Optionally specifies the folder for which jobs should be returned. The directory is determined
from the root folder, i.e. the "live" directory.

.PARAMETER Recursive
Specifies that any sub-folders should be looked up when used with the -Directory parameter.
By default no sub-folders will be looked up for jobs.

.PARAMETER State
Specifies that only jobs are considered that an order is currently passing. This is identified by the
order's state attribute that corresponds to the job node's state attribute.
This parameter requires use of the -JobChain parameter. If used with the -OrderId parameter then
only jobs for that order are considered, otherwise jobs for any orders in the given job chain are considered.

.PARAMETER ExcludeJob
This parameter accepts a single job path or an array of job paths that are excluded from the results.

.PARAMETER RegEx
Specifies a regular expression that filters the jobs to be returned.
The regular expression is applied to the path and name of jobs.

.PARAMETER DateFrom
Specifies the date starting from which history items should be returned.
Consider that a UTC date has to be provided.

Default: Begin of the current day as a UTC date

.PARAMETER DateTo
Specifies the date until which history items should be returned.
Consider that a UTC date has to be provided.

Default: End of the current day as a UTC date

.PARAMETER RelativeDateFrom
Specifies a relative date starting from which history items should be returned, e.g.

* -1s, -2s: one second ago, two seconds ago
* -1m, -2m: one minute ago, two minutes ago
* -1h, -2h: one hour ago, two hours ago
* -1d, -2d: one day ago, two days ago
* -1w, -2w: one week ago, two weeks ago
* -1M, -2M: one month ago, two months ago
* -1y, -2y: one year ago, two years ago

Optionally a time offset can be specified, e.g. -1d+02:00, as otherwise midnight UTC is assumed.
Alternatively a timezone offset can be added, e.g. by using -1d+TZ, that is calculated by the cmdlet
for the timezone that is specified with the -Timezone parameter.

This parameter takes precedence over the -DateFrom parameter.

.PARAMETER RelativeDateTo
Specifies a relative date until which history items should be returned, e.g.

* -1s, -2s: one second ago, two seconds ago
* -1m, -2m: one minute ago, two minutes ago
* -1h, -2h: one hour ago, two hours ago
* -1d, -2d: one day ago, two days ago
* -1w, -2w: one week ago, two weeks ago
* -1M, -2M: one month ago, two months ago
* -1y, -2y: one year ago, two years ago

Optionally a time offset can be specified, e.g. -1d+02:00, as otherwise midnight UTC is assumed.
Alternatively a timezone offset can be added, e.g. by using -1d+TZ, that is calculated by the cmdlet
for the timezone that is specified with the -Timezone parameter.

This parameter takes precedence over the -DateFrom parameter.

.PARAMETER Timezone
Specifies the timezone to which dates should be converted in the history information.
A timezone can e.g. be specified like this:

  Get-JSTaskHistory -Timezone (Get-Timezone -Id 'GMT Standard Time')

All dates in JobScheduler are UTC and can be converted e.g. to the local time zone like this:

  Get-JSTaskHistory -Timezone (Get-Timezone)

Default: Dates are returned in UTC.

.PARAMETER Limit
Specifies the max. number of history items for task executions to be returned.
The default value is 10000, for an unlimited number of items the value -1 can be specified.

.PARAMETER Successful
Returns history information for successfully completed tasks.

.PARAMETER Failed
Returns history information for failed tasks.

.PARAMETER Incomplete
Specifies that history information for running tasks should be returned.

.OUTPUTS
This cmdlet returns an array of history items.

.EXAMPLE
$items = Get-JobSchedulerTaskHistory

Returns today's task execution history for any jobs.

.EXAMPLE
$items = Get-JobSchedulerTaskHistory -RegEx '^/sos'

Returns today's task execution history for any jobs from the /sos folder.

.EXAMPLE
$items = Get-JobSchedulerTaskHistory -RegEx 'report'

Returns today's task execution history for jobs that contain the string
'report' in the job path.

.EXAMPLE
$items = Get-JobSchedulerTaskHistory -Timezone (Get-Timezone)

Returns today's task execution history for any jobs with dates being converted to the local timezone.

.EXAMPLE
$items = Get-JobSchedulerTaskHistory -Timezone (Get-Timezone -Id 'GMT Standard Time')

Returns today's task execution history for any jobs with dates being converted to the GMT timezone.

.EXAMPLE
$items = Get-JobSchedulerTaskHistory -Job /sos/dailyplan/CreateDailyPlan

Returns today's task execution history for a given job.

.EXAMPLE
$items = Get-JobSchedulerTaskHistory -JobChain /sos/dailyplan/CreateDailyPlan

Returns today's task execution history for jobs in the given job chain.

.EXAMPLE
$items = Get-JobSchedulerTaskHistory -ExcludeJob /sos/dailyplan/CreateDailyPlan, /sos/housekeeping/scheduler_rotate_log

Returns today's task execution history for any jobs excluding the specified job paths.

.EXAMPLE
$items = Get-JobSchedulerTaskHistory -Successful -DateFrom "2020-08-11 14:00:00Z"

Returns the task execution history for successfully completed jobs that started after the specified UTC date and time.

.EXAMPLE
$items = Get-JobSchedulerTaskHistory -Failed -DateFrom (Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(-7).ToUniversalTime()

Returns the task execution history for any failed jobs for the last seven days.

.EXAMPLE
$items = Get-JobSchedulerTaskHistory -RelativeDateFrom -7d

Returns the task execution history for the last seven days.
The history is reported starting from midnight UTC.

.EXAMPLE
$items = Get-JobSchedulerTaskHistory -RelativeDateFrom -7d+01:00

Returns the task execution history for the last seven days.
The history is reported starting from 1 hour after midnight UTC.

.EXAMPLE
$items = Get-JobSchedulerTaskHistory -RelativeDateFrom -7d+TZ

Returns the task execution history for any jobs for the last seven days.
The history is reported starting from midnight in the same timezone that is used with the -Timezone parameter.

.EXAMPLE
$items = Get-JobSchedulerTaskHistory -RelativeDateFrom -1w

Returns the task execution history for the last week.

.EXAMPLE
$items = Get-JobSchedulerTaskHistory -Directory /sos -Recursive -Successful -Failed

Returns today's task execution history for any completed tasks from the "/sos" directory
and any sub-folders recursively.

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
    [string] $OrderId,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Recursive,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $State,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string[]] $ExcludeJob,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $RegEx,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [DateTime] $DateFrom = (Get-Date -Hour 0 -Minute 0 -Second 0).ToUniversalTime(),
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [DateTime] $DateTo = (Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(1).ToUniversalTime(),
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $RelativeDateFrom,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $RelativeDateTo,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [TimeZoneInfo] $Timezone = (Get-Timezone -Id 'UTC'),
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int[]] $TaskId,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $Limit,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Successful,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Failed,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Incomplete
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-JobSchedulerStopWatch

        $jobs = @()
        $orders = @()
        $folders = @()
        $historyStates = @()
        $excludeJobs = @()
        $taskIds = @()
    }

    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, JobChain=$JobChain Job=$Job"

        if ( !$Directory -and !$JobChain -and !$Job -and !$TaskId )
        {
            throw "$($MyInvocation.MyCommand.Name): no directory, job chain or job specified, use -Directory, -JobChain, -Job or -TaskId"
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

        if ( $OrderId )
        {
            if ( (Get-JobSchedulerObject-Basename $OrderId) -ne $OrderId ) # order id includes a directory
            {
                $Directory = Get-JobSchedulerObject-Parent $OrderId
            } # order id includes no directory
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

        if ( $Directory -eq '/' -and !$OrderId -and !$JobChain -and !$Job -and !$Recursive )
        {
            $Recursive = $true
        }

        if ( $Successful )
        {
            $historyStates += 'SUCCESSFUL'
        }

        if ( $Failed )
        {
            $historyStates += 'FAILED'
        }

        if ( $Incomplete )
        {
            $historyStates += 'INCOMPLETE'
        }

        if ( $JobChain )
        {
            $objOrder = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'jobChain' -value $JobChain -InputObject $objOrder

            if ( $OrderId )
            {
                Add-Member -Membertype NoteProperty -Name 'orderId' -value $OrderId -InputObject $objOrder
            }

            if ( $State )
            {
                Add-Member -Membertype NoteProperty -Name 'state' -value $State -InputObject $objOrder
            }

            $orders += $objOrder
        }

        if ( $Job ) {
            $objJob = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'job' -value $Job -InputObject $objJob
            $jobs += $objJob
        }

        if ( !$JobChain -and $Directory )
        {
            $objFolder = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'folder' -value $Directory -InputObject $objFolder
            Add-Member -Membertype NoteProperty -Name 'recursive' -value ($Recursive -eq $true) -InputObject $objFolder
            $folders += $objFolder
        }

        if ( $ExcludeJob )
        {
            foreach( $excludeJobItem in $ExcludeJob )
            {
                $objExcludeJob = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'job' -value $excludeJobItem -InputObject $objExcludeJob
                $excludeJobs += $objExcludeJob
            }
        }

        if ( $TaskId )
        {
            $taskIds += $TaskId
        }
    }

    End
    {
        # PowerShell/.NET does not create date output in the target timezone but with the local timezone only, let's work around this:
        $timezoneOffsetPrefix = if ( $Timezone.BaseUtcOffset.toString().startsWith( '-' ) ) { '-' } else { '+' }
        $timezoneOffsetHours = [Math]::Abs($Timezone.BaseUtcOffset.hours)

        if ( $Timezone.SupportsDaylightSavingTime -and $Timezone.IsDaylightSavingTime( (Get-Date) ) )
        {
            $timezoneOffsetHours += 1
        }

        [string] $timezoneOffset = "$($timezoneOffsetPrefix)$($timezoneOffsetHours.ToString().PadLeft( 2, '0' )):$($Timezone.BaseUtcOffset.Minutes.ToString().PadLeft( 2, '0' ))"

        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

        if ( $jobs )
        {
            Add-Member -Membertype NoteProperty -Name 'jobs' -value $jobs -InputObject $body
        }

        if ( $excludeJobs )
        {
            Add-Member -Membertype NoteProperty -Name 'excludeJobs' -value $excludeJobs -InputObject $body
        }

        if ( $RegEx )
        {
            Add-Member -Membertype NoteProperty -Name 'regex' -value $RegEx -InputObject $body
        }

        if ( $DateFrom -or $RelativeDateFrom )
        {
            if ( $RelativeDateFrom )
            {
                if ( $RelativeDateFrom.endsWith( '+TZ' ) )
                {
                    $RelativeDateFrom = $RelativeDateFrom.Substring( 0, $RelativeDateFrom.length-3 ) + $timezoneOffset
                }
                Add-Member -Membertype NoteProperty -Name 'dateFrom' -value $RelativeDateFrom -InputObject $body
            } else {
                Add-Member -Membertype NoteProperty -Name 'dateFrom' -value ( Get-Date (Get-Date $DateFrom).ToUniversalTime() -Format 'u').Replace(' ', 'T') -InputObject $body
            }
        }

        if ( $DateTo -or $RelativeDateTo )
        {
            if ( $RelativeDateTo )
            {
                if ( $RelativeDateTo.endsWith( '+TZ' ) )
                {
                    $RelativeDateTo = $RelativeDateTo.Substring( 0, $RelativeDateTo.length-3 ) + $timezoneOffset
                }
                Add-Member -Membertype NoteProperty -Name 'dateTo' -value $RelativeDateTo -InputObject $body
            } else {
                Add-Member -Membertype NoteProperty -Name 'dateTo' -value ( Get-Date (Get-Date $DateTo).ToUniversalTime() -Format 'u').Replace(' ', 'T') -InputObject $body
            }
        }

        if ( $folders )
        {
            Add-Member -Membertype NoteProperty -Name 'folders' -value $folders -InputObject $body
        }

        if ( $Limit )
        {
            Add-Member -Membertype NoteProperty -Name 'limit' -value $Limit -InputObject $body
        }

        if ( $historyStates )
        {
            Add-Member -Membertype NoteProperty -Name 'historyStates' -value $historyStates -InputObject $body
        }

        if ( $orders )
        {
            Add-Member -Membertype NoteProperty -Name 'orders' -value $orders -InputObject $body
        }

        if ( $taskIds )
        {
            Add-Member -Membertype NoteProperty -Name 'taskIds' -value $taskIds -InputObject $body
        }

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest '/tasks/history' $requestBody

        if ( $response.StatusCode -eq 200 )
        {
            $returnHistoryItems = ( $response.Content | ConvertFrom-JSON ).history
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }

        if ( $Timezone.Id -eq 'UTC' )
        {
            $returnHistoryItems
        } else {
            $returnHistoryItems | Select-Object -Property `
                                           jobschedulerId, `
                                           clusterMember, `
                                           taskId, `
                                           job, `
                                           state, `
                                           @{name='startTime'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.startTime)".Substring(0, 19), 'UTC'), $Timezone ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}, `
                                           @{name='endTime';  expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.endTime)".SubString(0,19), 'UTC'), $($Timezone) ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}, `
                                           criticality, `
                                           exitCode, `
                                           @{name='surveyDate'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.surveyDate)".SubString(0, 19), 'UTC'), $($Timezone) ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}
        }

        if ( $returnHistoryItems.count )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($returnHistoryItems.count) history items found"
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no history items found"
        }

        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
