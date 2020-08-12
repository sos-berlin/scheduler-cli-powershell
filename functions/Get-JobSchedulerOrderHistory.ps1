function Get-JobSchedulerOrderHistory
{
<#
.SYNOPSIS
Returns the order execution history for job chains.

.DESCRIPTION
History information is returned for orders from a JobScheduler Master. 
Order executions can be selected by job chain, order ID, folder, history status etc.

The history information retured includes start time, end time, return code etc.

.PARAMETER JobChain
Optionally specifies the path and name of a job chain for which history information is returned.
If the name of a job chain is specified then the -Directory parameter is used to determine the folder.
Otherwise the -JobChain parameter is assumed to include the full path and name of the job chain.

One of the parameters -Directory or -JobChain has to be specified.

.PARAMETER OrderId
Optionally specifies the identifier of an order to limit results to that order.
This parameter requires use of the -JobChain parameter.

.PARAMETER Directory
Optionally specifies the folder for which jobs should be returned. The directory is determined
from the root folder, i.e. the "live" directory.

.PARAMETER Recursive
Specifies that any sub-folders should be looked up when used with the -Directory parameter. 
By default no sub-folders will be looked up for jobs.

.PARAMETER ExcludeOrder
This parameter accepts a single job chain path or an array of job chain paths that are excluded from the results.
Optionally the job chain path can be appended an order ID separated by a semicolon.

.PARAMETER RegEx
Specifies a regular expression that filters the orders to be returned.
The regular expression is applied to the path and ID of orders.

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

Optionally a timezone offset can be specified, e.g. -1d+02:00, as otherwise a UTC date is assumed.
This parameter takes precedence over the -DateFrom parameter.

.PARAMETER RelativeDateTo
Specifies a relative date until which history items should be returned, e.g. 

* -1d, -2d: one day ago, two days ago
* -1w, -2w: one week ago, two weeks ago
* -1M, -2M: one month ago, two months ago
* -1y, -2y: one year ago, two years ago

Optionally a timezone offset can be specified, e.g. -1d+02:00, as otherwise a UTC date is assumed.
This parameter takes precedence over the -DateTo parameter.

.PARAMETER Timezone
Specifies the timezone to which dates should be converted in the history information.
A timezone can e.g. be specified like this: 

  Get-JSOrderHistory -Timezone (Get-Timezone -Id 'GMT Standard Time')

All dates in JobScheduler are UTC and can be converted e.g. to the local time zone like this:

  Get-JSOrderHistory -Timezone (Get-Timezone)

Default: Dates are returned in UTC.

.PARAMETER Limit
Specifies the max. number of history items for order executions to be returned.
The default value is 10000, for an unlimited number of items the value -1 can be specified.

.PARAMETER Successful
Returns history information for successfully completed orders.

.PARAMETER Failed
Returns history information for failed orders.

.PARAMETER Incomplete
Specifies that history information for running orders should be returned.

.OUTPUTS
This cmdlet returns an array of history items.

.EXAMPLE
$items = Get-JobSchedulerOrderHistory

Returns today's order execution history for any orders.

.EXAMPLE
$items = Get-JobSchedulerOrderHistory -RegEx '^/sos'

Returns today's order execution history for any orders from the /sos folder.

.EXAMPLE
$items = Get-JobSchedulerOrderHistory -RegEx 'report'

Returns today's order execution history for orders that contain the string
'report' in the order's path.

.EXAMPLE
$items = Get-JobSchedulerOrderHistory -Timezone (Get-Timezone)

Returns today's order execution history for any orders with dates being converted to the local timezone.

.EXAMPLE
$items = Get-JobSchedulerOrderHistory -Timezone (Get-Timezone -Id 'GMT Standard Time')

Returns today's order execution history for any orders with dates being converted to the GMT timezone.

.EXAMPLE
$items = Get-JobSchedulerOrderHistory -JobChain /sos/dailyplan/CreateDailyPlan

Returns today's order execution history for a given job chain.

.EXAMPLE
$items = Get-JobSchedulerOrderHistory -ExcludeOrder /sos/dailyplan/CreateDailyPlan, /sos/notification/SystemNotifier:MonitorSystem

Returns today's order execution history for any orders excluding orders from the specified job chain paths.
The job chain path '/sos/notification/SystemNotifier' is appended the order ID 'MonitorSystem' separated by a semicolon
to indicate that the specified order ID only is excluded from the results.

.EXAMPLE
$items = Get-JobSchedulerOrderHistory -Successful -DateFrom "2020-08-11 14:00:00Z"

Returns the order execution history for successfully completed orders that started after the specified UTC date and time.

.EXAMPLE
$items = Get-JobSchedulerOrderHistory -Failed -DateFrom (Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(-7).ToUniversalTime()

Returns the order execution history for any failed orders for the last seven days.

.EXAMPLE
$items = Get-JobSchedulerOrderHistory -RelativeDateFrom -7d

Returns the order execution history for the last seven days.
The history is reported starting from midnight UTC.

.EXAMPLE
$items = Get-JobSchedulerOrderHistory -RelativeDateFrom -7d+01:00

Returns the order execution history for the last seven days.
The history is reported starting from 1 hour after midnight UTC.

.EXAMPLE
$items = Get-JobSchedulerOrderHistory -RelativeDateFrom -7d+TZ

Returns the order execution history for the last seven days.
The history is reported starting from midnight in the same timezone that is used with the -Timezone parameter.

.EXAMPLE
$items = Get-JobSchedulerOrderHistory -RelativeDateFrom -1w

Returns the order execution history for any jobs for the last week.

.EXAMPLE
$items = Get-JobSchedulerOrderHistory -Directory /sos -Recursive -Successful -Failed

Returns today's order execution history for any completed orders from the "/sos" directory
and any sub-folders recursively.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OrderId,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Recursive,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string[]] $ExcludeOrder,
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

        $orders = @()
        $folders = @()
        $historyStates = @()
        $excludeOrders = @()
    }
        
    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, JobChain=$JobChain, OrderId=$OrderId"
    
        if ( !$Directory -and !$JobChain )
        {
            throw "$($MyInvocation.MyCommand.Name): no directory or job chain specified, use -Directory or -JobChain"
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
            
            $orders += $objOrder
        }

        if ( !$JobChain -and $Directory )
        {
            $objFolder = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'folder' -value $Directory -InputObject $objFolder
            Add-Member -Membertype NoteProperty -Name 'recursive' -value ($Recursive -eq $true) -InputObject $objFolder
            $folders += $objFolder
        }

        if ( $ExcludeOrder )
        {
            foreach( $excludeOrderItem in $ExcludeOrder )
            {
                $objExcludeOrder = New-Object PSObject
                if ( $excludeOrderItem.split(':').count -gt 1 )
                {
                    $excludeOrderItems = $excludeOrderItem.split(':')
                    Add-Member -Membertype NoteProperty -Name 'jobChain' -value $excludeOrderItems[0] -InputObject $objExcludeOrder
                    Add-Member -Membertype NoteProperty -Name 'orderId' -value $excludeOrderItems[1] -InputObject $objExcludeOrder
                } else {
                    Add-Member -Membertype NoteProperty -Name 'jobChain' -value $excludeOrderItem -InputObject $objExcludeOrder
                }
                $excludeOrders += $objExcludeOrder
            }
        }
    }
    
    End
    {
        # PowerShell/.NET does not create date output in the target timezone but with the local timezone only, let's work around this:
        $timezoneOffsetPrefix = if ( $Timezone.BaseUtcOffset.toString().startsWith( '-' ) ) { '-' } else { '+' }
        $timezoneOffsetHours = $Timezone.BaseUtcOffset.Hours

        if ( $Timezone.SupportsDaylightSavingTime )
        {
            $timezoneOffsetHours += 1
        }
                    
        [string] $timezoneOffset = "$($timezoneOffsetPrefix)$($timezoneOffsetHours.ToString().PadLeft( 2, '0' )):$($Timezone.BaseUtcOffset.Minutes.ToString().PadLeft( 2, '0' ))"

        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

        if ( $orders )
        {
            Add-Member -Membertype NoteProperty -Name 'orders' -value $orders -InputObject $body
        }

        if ( $excludeOrders )
        {
            Add-Member -Membertype NoteProperty -Name 'excludeOrders' -value $excludeOrders -InputObject $body
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

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest '/orders/history' $requestBody
        
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
                                           historyId, `
                                           orderId, `
                                           jobChain, `
                                           path, `
                                           state, `
                                           @{name='startTime'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.startTime)".Substring(0, 19), 'UTC'), $Timezone ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}, `
                                           @{name='endTime';  expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.endTime)".SubString(0,19), 'UTC'), $($Timezone) ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}, `
                                           node, `
                                           exitCode, `
                                           @{name='surveyDate'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.surveyDate)".SubString(0, 19), 'UTC'), $($Timezone) ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}
        }

        if ( $returnHistoryItems.count )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($returnHistoryItems.count) history items found"
        } else {s
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no history items found"
        }
        
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
