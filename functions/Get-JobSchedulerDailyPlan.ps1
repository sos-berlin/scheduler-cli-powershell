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
Optionally specifies the path and name of an order for which daily plan items should be returned.
If the name of an order is specified then the -Directory parameter is used to determine the folder.
Otherwise the -OrderId parameter is assumed to include the full path and name of the order.

.PARAMETER Job
Optionally specifies the path and name of a job for which daily plan items should be returned.
If the name of a job is specified then the -Directory parameter is used to determine the folder.
Otherwise the -Job parameter is assumed to include the full path and name of the job.

.PARAMETER Directory
Optionally specifies the folder for which daily plan items should be returned. The directory is determined
from the root folder, i.e. the "live" directory and should start with a "/".

.PARAMETER Recursive
When used with the -Directory parameter then any sub-folders of the specified directory will be looked up.

.PARAMETER DateFrom
Optionally specifies the date starting from which daily plan items should be returned.
Consider that a UTC date has to be provided.

Default: Begin of the current day as a UTC date

.PARAMETER DateTo
Optionally specifies the date until which daily plan items should be returned.
Consider that a UTC date has to be provided.

Default: End of the current day as a UTC date

.PARAMETER Timezone
Specifies the timezone to which dates should be converted in the history information.
A timezone can e.g. be specified like this: 

  Get-JSTaskHistory -Timezone (Get-Timezone -Id 'GMT Standard Time')

All dates in JobScheduler are UTC and can be converted e.g. to the local time zone like this:

  Get-JSTaskHistory -Timezone (Get-Timezone)

Default: Dates are returned in UTC.

.PARAMETER Late
Specifies that daily plan items are returned that did start later than expected.

.PARAMETER Successful
Specifies that daily plan items are returned that did complete successfully.

.PARAMETER Failed
Specifies that daily plan items are returned that did complete with errors.

.PARAMETER Incomplete
Specifies that daily plan items are returned that did not yet complete.

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
$items = Get-JobSchedulerDailyPlan -DateTo (Get-Date).AddDays(3)

Returns the daily plan items for the next 3 days.

.EXAMPLE
$items = Get-JobSchedulerDailyPlan -Failed -Late

Returns the daily plan items that failed or started later than expected.

.EXAMPLE
$items = Get-JobSchedulerDailyPlan -JobChain /holidays/some_job_chain

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
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Recursive,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [DateTime] $DateFrom = (Get-Date -Hour 0 -Minute 0 -Second 0).ToUniversalTime(),
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [DateTime] $DateTo = (Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(1).ToUniversalTime(),
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

        if ( $Directory -ne '/' )
        {
            $folders += $Directory        
        }
    }

    End
    {
        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
        Add-Member -Membertype NoteProperty -Name 'isJobStream' -value ( $IsJobStream -eq $true ) -InputObject $body

        if ( $DateFrom )
        {
            Add-Member -Membertype NoteProperty -Name 'dateFrom' -value ( Get-Date (Get-Date $DateFrom).ToUniversalTime() -Format 'u').Replace(' ', 'T') -InputObject $body
        }

        if ( $DateTo )
        {
            Add-Member -Membertype NoteProperty -Name 'dateTo' -value ( Get-Date (Get-Date $DateTo).ToUniversalTime() -Format 'u').Replace(' ', 'T') -InputObject $body
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
            # PowerShell/.NET does not create date output in the target timezone but with the local timezone only, let's work around this:
            $prefix = if ( $Timezone.BaseUtcOffset.toString().startsWith( '-' ) ) { '-' } else { '+' }

            $hours = $Timezone.BaseUtcOffset.Hours
            if ( $Timezone.SupportsDaylightSavingTime )
            {
                $hours += 1
            }
                        
            [string] $timezoneOffset = "$($prefix)$($hours.ToString().PadLeft( 2, '0' )):$($Timezone.BaseUtcOffset.Minutes.ToString().PadLeft( 2, '0' ))"

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
                                           @{name='plannedStartTime'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( "$($_.plannedStartTime)", 'Utc'), $($Timezone) ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}, `
                                           @{name='expectedEndTime'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( "$($_.expectedEndTime)", 'Utc'), $($Timezone) ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}, `
                                           @{name='startTime'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( "$($_.startTime)", 'Utc'), $($Timezone) ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}, `
                                           @{name='endTime'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( "$($_.endTime)", 'Utc'), $($Timezone) ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}, `
                                           node, `
                                           error, `
                                           exitCode, `
                                           @{name='surveyDate'; expression={ ( [System.TimeZoneInfo]::ConvertTimeFromUtc( [datetime]::SpecifyKind( "$($_.surveyDate)", 'Utc'), $($Timezone) ) ).ToString("yyyy-MM-dd HH:mm:ss") + $timezoneOffset }}
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
