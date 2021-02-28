function Get-JobSchedulerJobStreamHistory
{
<#
.SYNOPSIS
Returns the execution history for job streams.

.DESCRIPTION
History information is returned for job streams from a JobScheduler Master.
Job stream executions can be selected by job stream name, history status etc.

The history information returned includes start time, end time, tasks etc.

.PARAMETER JobStream
Optionally specifies the path and name of a job stream. Such names are unique across
all folders that job streams are stored to.

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

  Get-JSJobStreamHistory -Timezone (Get-Timezone -Id 'GMT Standard Time')

All dates in JobScheduler are UTC and can be converted e.g. to the local time zone like this:

  Get-JSJobStreamHistory -Timezone (Get-Timezone)

Default: Dates are returned in UTC.

.PARAMETER Limit
Specifies the max. number of history items for job stream executions to be returned.
The default value is 10000, for an unlimited number of items the value -1 can be specified.

.PARAMETER Successful
Returns history information for successfully completed job streams.

.PARAMETER Failed
Returns history informiaton for failed job streams.

.PARAMETER Incomplete
Specifies that history information for running job streams should be returned.

.PARAMETER WithTasks
Specifies that to the history information that is returned an additional record for each task is added.
This allows to receive the list of tasks executed for each job stream in the order of their start time.

.OUTPUTS
This cmdlet returns an array of history items.

.EXAMPLE
$items = Get-JobSchedulerJobStreamHistory

Returns today's execution history for any job streams.

.EXAMPLE
$items = Get-JobSchedulerJobStreamHistory -Timezone (Get-Timezone)

Returns today's execution history for any job streams with dates being converted to the local timezone.

.EXAMPLE
$items = Get-JobSchedulerJobStreamHistory -Timezone (Get-Timezone -Id 'GMT Standard Time')

Returns today's execution history for any job streams with dates being converted to the GMT timezone.

.EXAMPLE
$items = Get-JobSchedulerJobStreamHistory -JobStream /test/globals/jobstream1

Returns today's execution history for a given job stream.

.EXAMPLE
$items = Get-JobSchedulerJobStreamHistory -Successful -DateFrom "2020-08-11 14:00:00Z"

Returns the execution history for successfully completed job streams that started after the specified UTC date and time.

.EXAMPLE
$items = Get-JobSchedulerJobStreamHistory -RelativeDateFrom -7d

Returns the job stream execution history for the last seven days.
The history is reported starting from midnight UTC.

.EXAMPLE
$items = Get-JobSchedulerJobStreamHistory -RelativeDateFrom -7d+01:00

Returns the job stream execution history for the last seven days.
The history is reported starting from 1 hour after midnight UTC.

.EXAMPLE
$items = Get-JobSchedulerJobStreamHistory -RelativeDateFrom -7d+TZ

Returns the job stream execution history for any jobs for the last seven days.
The history is reported starting from midnight in the same timezone that is used with the -Timezone parameter.

.EXAMPLE
$items = Get-JobSchedulerJobStreamHistory -RelativeDateFrom -1w

Returns the job stream execution history for the last week.

.EXAMPLE
$items = Get-JobSchedulerJobStreamHistory -Failed -DateFrom (Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(-7).ToUniversalTime()

Returns the execution history for any failed job streams for the last seven days.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobStream,
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
    [int] $Limit,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Successful,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Failed,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Incomplete,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $WithTasks
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-JobSchedulerStopWatch

        $historyStates = @()
    }

    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter JobStream=$JobStream"

        if ( $Successful -or $Failed )
        {
            throw "Parameters -Successful and -Failed are currently not supported"
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
            $historyStates += 'RUNNING'
        }
    }

    End
    {
        # PowerShell/.NET does not create date output in the target timezone but with the local timezone only, let's work around this:
        $timezoneOffsetPrefix = if ( $Timezone.BaseUtcOffset.toString().startsWith( '-' ) ) { '-' } else { '+' }
        $timezoneOffsetHours = $Timezone.BaseUtcOffset.Hours

        if ( $Timezone.SupportsDaylightSavingTime -and $Timezone.IsDaylightSavingTime( (Get-Date) ) )
        {
            $timezoneOffsetHours += 1
        }

        [string] $timezoneOffset = "$($timezoneOffsetPrefix)$($timezoneOffsetHours.ToString().PadLeft( 2, '0' )):$($Timezone.BaseUtcOffset.Minutes.ToString().PadLeft( 2, '0' ))"

        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

        if ( $JobStream )
        {
            Add-Member -Membertype NoteProperty -Name 'jobStream' -value $JobStream -InputObject $body
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

        if ( $Limit )
        {
            Add-Member -Membertype NoteProperty -Name 'limit' -value $Limit -InputObject $body
        }

        if ( $historyStates )
        {
            Add-Member -Membertype NoteProperty -Name 'status' -value $historyStates -InputObject $body
        }

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest '/jobstreams/sessions' $requestBody

        if ( $response.StatusCode -eq 200 )
        {
            $returnHistoryItems = ( $response.Content | ConvertFrom-JSON ).jobstreamSessions
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }

        if ( $Timezone.Id -eq 'UTC' )
        {
            $resultHistoryItems = $returnHistoryItems | Select-Object -Property `
                                           jobschedulerId, `
                                           @{name='jobStreamInstanceId'; expression={ $_.id }}, `
                                           @{name='jobStreamInstance'; expression={ $_.session }}, `
                                           jobStreamId, `
                                           jobStream, `
                                           jobStreamStarter, `
                                           @{name='jobStreamTasks'; expression={ $_.jobstreamTasks }}, `
                                           @{name='state'; expression={ if ( $_.running -eq $false ) { $stateText = 'INCOMPLETE'; $stateSeverity=1 } else { $stateText = 'SUCCESS'; $stateSeverity = 0 } ; $stateObj = New-Object PSObject; Add-Member -Membertype NoteProperty -Name '_text' -value $stateText -InputObject $stateObj; Add-Member -Membertype NoteProperty -Name 'severity' -value $stateSeverity -InputObject $stateObj; $stateObj }}, `
                                           @{name='startTime'; expression={ $_.started }}, `
                                           @{name='endTime'; expression={ $_.ended }}, `
                                           @{name='surveyDate'; expression={ $_.ended }}
        } else {
            $resultHistoryItems = $returnHistoryItems | Select-Object -Property `
                                           jobschedulerId, `
                                           @{name='jobStreamInstanceId'; expression={ $_.id }}, `
                                           @{name='jobStreamInstance'; expression={ $_.session }}, `
                                           jobStreamId, `
                                           jobStream, `
                                           jobStreamStarter, `
                                           @{name='jobStreamTasks'; expression={$_.jobstreamTasks }}, `
                                           @{name='state'; expression={ if ( $_.running -eq $false ) { $stateText = 'INCOMPLETE'; $stateSeverity=1 } else { $stateText = 'SUCCESS'; $stateSeverity = 0 } ; $stateObj = New-Object PSObject; Add-Member -Membertype NoteProperty -Name '_text' -value $stateText -InputObject $stateObj; Add-Member -Membertype NoteProperty -Name 'severity' -value $stateSeverity -InputObject $stateObj; $stateObj }}, `
                                           @{name='startTime'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.started)".Substring(0, 19), 'UTC'), $Timezone ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}, `
                                           @{name='endTime'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.ended)".SubString(0,19), 'UTC'), $($Timezone) ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}, `
                                           @{name='surveyDate'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.ended)".SubString(0, 19), 'UTC'), $($Timezone) ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}
        }

        if ( $WithTasks )
        {
            foreach( $resultHistoryItem in $resultHistoryItems )
            {
                $resultHistoryItem | Select-Object -Property `
                                            jobschedulerId, `
                                            jobStreamInstanceId, `
                                            jobStreamId, `
                                            jobStream, `
                                            jobStreamStarter, `
                                            @{name='clusterMember'; expression={ '' }}, `
                                            @{name='taskId'; expression={ '' }}, `
                                            @{name='job'; expression={ '' }}, `
                                            @{name='criticality'; expression={ '' }}, `
                                            @{name='exitCode'; expression={ '' }}, `
                                            state, `
                                            startTime, `
                                            endTime, `
                                            surveyDate
                Get-JobSchedulerTaskHistory -TaskId $resultHistoryItem.jobStreamTasks.id | Select-Object -Property `
                                                jobSchedulerId, `
                                                @{name='jobStreamInstanceId'; expression={ $resultHistoryItem.jobStreamInstanceId }}, `
                                                @{name='jobStreamId'; expression={ $resultHistoryItem.jobStreamId }}, `
                                                @{name='jobStream'; expression={ $resultHistoryItem.jobStream }}, `
                                                @{name='jobStreamStarter'; expression={ $resultHistoryItem.jobStreamStarter }}, `
                                                clusterMember, `
                                                taskId, `
                                                job, `
                                                criticality, `
                                                exitCode, `
                                                state, `
                                                startTime, `
                                                endTime, `
                                                surveyDate
            }
        } else {
            $resultHistoryItems
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
