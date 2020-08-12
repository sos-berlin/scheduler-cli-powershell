function Get-JobSchedulerDailyPlan
{
<#
.SYNOPSIS
Returns the daily plan items for job streams, jobs and orders of JobScheduler.

.DESCRIPTION
The daily plan items for job streams, jobs and orders are returned.

.PARAMETER JobChain
Optionally specifies the path and name of a job chain for which daily plan items should be returned.
If the name of a job chain is specified then the -Directory parameter is used to determine the folder.
Otherwise the -JobChain parameter is assumed to include the full path and name of the job chain.

.PARAMETER OrderId
Optionally specifies the path and ID of an order for which daily plan items should be returned.
If an order ID is specified then the -Directory parameter is used to determine the folder.
Otherwise the -OrderId parameter is assumed to include the full path and ID of the order.

.PARAMETER Job
Optionally specifies the path and name of a job for which daily plan items should be returned.
If the name of a job is specified then the -Directory parameter is used to determine the folder.
Otherwise the -Job parameter is assumed to include the full path and name of the job.

.PARAMETER JobStream
Optionally specifies the name of a job stream for which daily plan items should be returned.
Job streams are unique across folders and are specified by name. 
Therefore the -Directory parameter is ignored if this parameter is used.

.PARAMETER Directory
Optionally specifies the folder for which daily plan items should be returned. The directory is determined
from the root folder, i.e. the "live" directory and should start with a "/".

.PARAMETER Recursive
When used with the -Directory parameter then any sub-folders of the specified directory will be looked up.

.PARAMETER RegEx
Specifies a regular expression that filters the items to be returned.
This applies to jobs, job chains, orders and job streams that are filtered by path including their name.

.PARAMETER DateFrom
Optionally specifies the date starting from which daily plan items should be returned.
Consider that a UTC date has to be provided.

Default: Begin of the current day as a UTC date

.PARAMETER DateTo
Optionally specifies the date until which daily plan items should be returned.
Consider that a UTC date has to be provided.

Default: End of the current day as a UTC date

.PARAMETER RelativeDateFrom
Specifies a relative date starting from which daily plan items should be returned, e.g. 

* -1d, -2d: one day ago, two days ago
* +1d, +2d: one day later, two days later
* -1w, -2w: one week ago, two weeks ago
* +1w, +2w: one week later, two weeks later
* -1M, -2M: one month ago, two months ago
* +1M, +2M: one month later, two months later
* -1y, -2y: one year ago, two years ago
* +1y, +2y: one year later, two years later

Optionally a timezone offset can be specified, e.g. -1d+02:00, as otherwise a UTC date is assumed.
This parameter takes precedence over the -DateFrom parameter.

.PARAMETER RelativeDateTo
Specifies a relative date until which daily plan items should be returned, e.g. 

* -1d, -2d: one day ago, two days ago
* +1d, +2d: one day later, two days later
* -1w, -2w: one week ago, two weeks ago
* +1w, +2w: one week later, two weeks later
* -1M, -2M: one month ago, two months ago
* +1M, +2M: one month later, two months later
* -1y, -2y: one year ago, two years ago
* +1y, +2y: one year later, two years later

Optionally a timezone offset can be specified, e.g. -1d+02:00, as otherwise a UTC date is assumed.
This parameter takes precedence over the -DateTo parameter.

.PARAMETER Timezone
Specifies the timezone to which dates should be converted in the daily plan information.
A timezone can e.g. be specified like this: 

  Get-JSDailyPlan -Timezone (Get-Timezone -Id 'GMT Standard Time')

All dates in JobScheduler are UTC and can be converted e.g. to the local time zone like this:

  Get-JSDailyPlan -Timezone (Get-Timezone)

Default: Dates are returned in UTC.

.PARAMETER Late
Specifies that daily plan items are returned that are late or that started later than expected.

.PARAMETER Successful
Specifies that daily plan items are returned completed successfully.

.PARAMETER Failed
Specifies that daily plan items are returned that completed with errors.

.PARAMETER Incomplete
Specifies that daily plan items are returned for jobs, orders, job streams that did not yet complete.

.PARAMETER Planned
Specifies that daily plan items are returned that did not yet start.

.PARAMETER IsJobStream
Limits results to Job Streams only.

.OUTPUTS
This cmdlet returns an array of daily plan items.

.EXAMPLE
$items = Get-JobSchedulerDailyPlan

Returns daily plan items for the current day.

.EXAMPLE
$items = Get-JobSchedulerDailyPlan -RegEx '^/sos'

Returns today's daily plan for any items from the /sos folder.

.EXAMPLE
$items = Get-JobSchedulerDailyPlan -RegEx 'report'

Returns today's daily plan for items that contain the string
'report' in the path.

.EXAMPLE
$items = Get-JobSchedulerDailyPlan -Timezone (Get-Timezone)

Returns today's daily plan for any jobs with dates being converted to the local timezone.

.EXAMPLE
$items = Get-JobSchedulerDailyPlan -Timezone (Get-Timezone -Id 'GMT Standard Time')

Returns today's daily plan for any jobs with dates being converted to the GMT timezone.

.EXAMPLE
$items = Get-JobSchedulerDailyPlan -DateTo (Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(4).ToUniversalTime()

Returns the daily plan items for the next 3 days until midnight.

.EXAMPLE
$items = Get-JobSchedulerDailyPlan -RelativeDateFrom -7d

Returns the daily plan for the last seven days.
The daily plan is reported starting from midnight UTC.

.EXAMPLE
$items = Get-JobSchedulerDailyPlan -RelativeDateFrom -7d+01:00

Returns the daily plan for the last seven days.
The daily plan is reported starting from 1 hour after midnight UTC.

.EXAMPLE
$items = Get-JobSchedulerDailyPlan -RelativeDateFrom -7d+TZ

Returns the daily plan for the last seven days.
The daily plan is reported starting from midnight in the same timezone that is used with the -Timezone parameter.

.EXAMPLE
$items = Get-JobSchedulerDailyPlan -RelativeDateFrom -1w

Returns the daily plan for the last week.

.EXAMPLE
$items = Get-JobSchedulerDailyPlan -Failed -Late

Returns today's daily plan items for jobs that failed or are late, i.e. that did not start at the expected point in time.

.EXAMPLE
$items = Get-JobSchedulerDailyPlan -JobChain /sos/dailyplan/CreateDailyPlan

Returns the daily plan items for any orders of the given job chain.

.EXAMPLE
$items = Get-JobSchedulerDailyPlan -IsJobStream -Planned

Returns the daily plan items for job streams that are planned for the current day.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OrderId,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Job,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobStream,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Recursive,
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
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Late,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Successful,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Failed,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Incomplete,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Planned,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $IsJobStream
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch

        $jobs = @()
        $jobChains = @()
        $orderIds = @()
        $jobStreams = @()
        $folders = @()
        $states = @()
        $returnPlans = @()        
    }

    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, JobChain=$JobChain, OrderId=$OrderId"

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
            if ( (Get-JobSchedulerObject-Basename $OrderId) -ne $OrderId ) # order if includes a directory
            {
                $Directory = Get-JobSchedulerObject-Parent $OrderId
            } else { # order id includes no directory
                if ( $Directory -eq '/' )
                {
                    $OrderId = $Directory + $OrderId
                } else {
                    $OrderId = $Directory + '/' + $OrderId
                }
            }
        }

        if ( $Directory -eq '/' -and !$JobChain -and !$Job -and !$Recursive )
        {
            $Recursive = $true
        }

   
        if ( $Successful )
        {
            $states += 'SUCCESSFUL'
        }

        if ( $Failed )
        {
            $states += 'FAILED'
        }

        if ( $Incomplete )
        {
            $states += 'INCOMPLETE'
        }

        if ( $Planned )
        {
            $states += 'PLANNED'
        }


        if ( $Job )
        {
            $jobs = @( $Job )
        }

        if ( $JobChain )
        {
            $jobChains = @( $JobChain )
        }

        if ( $OrderId )
        {
            $orderIds = @( $OrderId )
        }

        if ( $JobStream )
        {
            $jobStreams = @( $JobStream )
        }

        if ( $Directory -ne '/' )
        {
            $folders += $Directory        
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
        Add-Member -Membertype NoteProperty -Name 'isJobStream' -value ( $IsJobStream -eq $true ) -InputObject $body

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

        if ( $states )
        {
            Add-Member -Membertype NoteProperty -Name 'states' -value $states -InputObject $body
        }

        if ( $Late )
        {
            Add-Member -Membertype NoteProperty -Name 'late' -value ( $Late -eq $true ) -InputObject $body
        }
        
        if ( $folders )
        {
            $objFolders = @()
            foreach( $folder in $folders )
            {
                $objFolder = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'folder' -value $folder -InputObject $objFolder
                Add-Member -Membertype NoteProperty -Name 'recursive' -value ( $Recursive -eq $true ) -InputObject $objFolder
                $objFolders += $objFolder
            }
            
            Add-Member -Membertype NoteProperty -Name 'folders' -value $objFolders -InputObject $body            
        }

        if ( $jobs )
        {
            Add-Member -Membertype NoteProperty -Name 'job' -value $jobs[0] -InputObject $body
        }

        if ( $jobChains )
        {
            Add-Member -Membertype NoteProperty -Name 'jobChain' -value $jobChains[0] -InputObject $body
        }

        if ( $orderIds )
        {
            Add-Member -Membertype NoteProperty -Name 'orderId' -value $orderIds[0] -InputObject $body
        }

        if ( $jobStreams )
        {
            Add-Member -Membertype NoteProperty -Name 'jobStream' -value $jobStreams[0] -InputObject $body
        }

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest '/plan' $requestBody
        
        if ( $response.StatusCode -eq 200 )
        {
            $returnDailyPlanItems = ( $response.Content | ConvertFrom-JSON ).planItems
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }


        if ( $Timezone.Id -eq 'UTC' )
        {
            $returnDailyPlanItems | Sort-Object plannedStartTime
        } else {
            $returnDailyPlanItems | Sort-Object plannedStartTime | Select-Object -Property `
                                           job, `
                                           jobChain, `
                                           orderId, `
                                           historyId, `
                                           state, `
                                           late, `
                                           jobSream, `
                                           startMode, `
                                           period, `
                                           @{name='plannedStartTime'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.plannedStartTime)".Substring(0, 19), 'UTC'), $Timezone ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}, `
                                           @{name='expectedEndTime';  expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.expectedEndTime)".SubString(0,19), 'UTC'), $($Timezone) ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}, `
                                           @{name='startTime'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.startTime)".Substring(0, 19), 'UTC'), $Timezone ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}, `
                                           @{name='endTime';  expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.endTime)".SubString(0,19), 'UTC'), $($Timezone) ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}, `
                                           node, `
                                           error, `
                                           exitCode, `
                                           @{name='surveyDate'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( [datetime] "$($_.surveyDate)".SubString(0, 19), 'UTC'), $($Timezone) ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}
        }

        if ( $returnDailyPlanItems.count )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($returnDailyPlanItems.count) Daily Plan items found"
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no Daily Plan items found"
        }
        
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
