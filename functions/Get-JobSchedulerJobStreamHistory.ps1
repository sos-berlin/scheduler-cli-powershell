function Get-JobSchedulerJobStreamHistory
{
<#
.SYNOPSIS
Returns the execution history for job streams.

.DESCRIPTION
History information is returned for job streams from a JobScheduler Master. 
Job stream executions can be selected by job stream name, history status etc.

The history information retured includes start time, end time, tasks etc.

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
Returns history information for successfully executed job streams.

.PARAMETER Failed
Returns history informiaton for failed job streams.

.PARAMETER Incomplete
Specifies that history information for running job streams should be returned.

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
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $State,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [DateTime] $DateFrom = (Get-Date -Hour 0 -Minute 0 -Second 0).ToUniversalTime(),
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [DateTime] $DateTo = (Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(1).ToUniversalTime(),
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [TimeZoneInfo] $Timezone = (Get-Timezone -Id 'UTC'),
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
        $stopWatch = Start-StopWatch

        $jobStreams = @()
        $historyStates = @()
    }
        
    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter JobStream=$JobStream"
    
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
        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

        if ( $JobStream )
        {
            Add-Member -Membertype NoteProperty -Name 'jobStream' -value $JobStream -InputObject $body
        }

        if ( $DateFrom )
        {
            Add-Member -Membertype NoteProperty -Name 'dateFrom' -value ( Get-Date (Get-Date $DateFrom).ToUniversalTime() -Format 'u').Replace(' ', 'T') -InputObject $body
        }

        if ( $DateTo )
        {
            Add-Member -Membertype NoteProperty -Name 'dateTo' -value ( Get-Date (Get-Date $DateTo).ToUniversalTime() -Format 'u').Replace(' ', 'T') -InputObject $body
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
            $returnHistoryItems | Select-Object -Property `
                                           jobschedulerId, `
                                           @{name='jobStreamSessionId'; expression={ $_.id }}, `
                                           @{name='jobStreamSession'; expression={ $_.session }}, `
                                           jobStreamId, `
                                           jobStream, `
                                           jobStreamStarter, `
                                           @{name='jobStreamTasks'; expression={ $_.jobstreamTasks }}, `
                                           @{name='state'; expression={ if ( $_.running -eq $false ) { 'INCOMPLETE' } else { 'SUCCESS' } }}, `
                                           @{name='startTime'; expression={ $_.started }}, `
                                           @{name='endTime'; expression={ $_.ended }}, `
                                           @{name='surveyDate'; expression={ $_.ended }}
        } else {
            # PowerShell/.NET does not create date output in the target timezone but with the local timezone only, let's work around this:
            $prefix = if ( $Timezone.BaseUtcOffset.toString().startsWith( '-' ) ) { '-' } else { '+' }

            $hours = $Timezone.BaseUtcOffset.Hours
            if ( $Timezone.SupportsDaylightSavingTime )
            {
                $hours += 1
            }
                        
            [string] $timezoneOffset = "$($prefix)$($hours.ToString().PadLeft( 2, '0' )):$($Timezone.BaseUtcOffset.Minutes.ToString().PadLeft( 2, '0' ))"

            $returnHistoryItems | Select-Object -Property `
                                           jobschedulerId, `
                                           @{name='jobStreamSessionId'; expression={ $_.id }}, `
                                           @{name='jobStreamSession'; expression={ $_.session }}, `
                                           jobStreamId, `
                                           jobStream, `
                                           jobStreamStarter, `
                                           @{name='jobStreamTasks'; expression={$_.jobstreamTasks }}, `
                                           @{name='state'; expression={ if ( $_.running -eq $false ) { 'INCOMPLETE' } else { 'SUCCESS' } }}, `
                                           @{name='startTime'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.started)".Substring(0, 19), 'UTC'), $Timezone ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}, `
                                           @{name='endTime'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.ended)".SubString(0,19), 'UTC'), $($Timezone) ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}, `
                                           @{name='surveyDate'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.ended)".SubString(0, 19), 'UTC'), $($Timezone) ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}
        }

        if ( $returnHistoryItems.count )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($returnHistoryItems.count) history items found"
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no history items found"
        }
        
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
