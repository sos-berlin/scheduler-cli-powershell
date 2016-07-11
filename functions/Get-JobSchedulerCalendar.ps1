function Get-JobSchedulerCalendar
{
<#
.SYNOPSIS
Shows the next start dates for jobs and orders of JobScheduler Master.

.DESCRIPTION
The next start date for jobs and orders is calculated by JobScheduler Master.
This cmdlet returns a list of start date objects that indicate the next start time.

.PARAMETER Directory
Optionally specifies the folder for which order and job start times should be returned. The directory is determined
from the root folder, i.e. the "live" directory.

.PARAMETER JobChain
Optionally specifies the path and name of a job chain for which order start times should be returned.
If the name of a job chain is specified then the -Directory parameter is used to determine the folder.
Otherwise the -JobChain parameter is assumed to include the full path and name of the job chain.

.PARAMETER Order
Optionally specifies the path and name of an order for which start times should be returned.
If the name of an order is specified then the -Directory parameter is used to determine the folder.
Otherwise the -Order parameter is assumed to include the full path and name of the order.

.PARAMETER Job
Optionally specifies the path and name of a job for which start times should be returned.
If the name of a job is specified then the -Directory parameter is used to determine the folder.
Otherwise the -Job parameter is assumed to include the full path and name of the job.

.PARAMETER Limit
Limits the number of entries that are returned in order avoid too large a result. 
Because calender entries are not sorted according to time but by object, this command does not return 
the next 100 entries but effectively 100 random entries.

The limit should be set high enough so that entries are not lost.

Default: 100

.PARAMETER Days
Optionally specifies the number of days starting from the current time for which
start dates are returned.

Default: 1

.PARAMETER FromDate
Optionally specifies the date starting from which start dates are calculated.

.PARAMETER ToDate
Optionally specifies the date for which the calculation of start dates ends.

.PARAMETER Display
Specifies that formatted output is displayed.

.PARAMETER NoOutputs
Specifies that no output is created, i.e. no objects are returned.

.OUTPUTS
This cmdlet returns an array of start date objects.

.EXAMPLE
$startDates = Get-JobSchedulerCalendar

Returns start dates for the next 24 hrs.

.EXAMPLE
$startDates = Get-JobSchedulerCalendar -Days 3

Returns the start dates for the next 3 days.

.EXAMPLE
$startDates = Get-JobSchedulerCalendar -FromDate 2016-06-01 -ToDate 2016-06-30

Returns the start dates between the specified dates.

.EXAMPLE
Get-JobSchedulerCalendar -Display

Displays formatted output.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Order,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Job,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $Limit = 100,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $Days = 1,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [DateTime] $FromDate,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [DateTime] $ToDate,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Display,
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $NoOutputs
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch
    }

    Process
    {
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
                if ( $Directory -ne '/' )
                {
                    # Write-Warning "$($MyInvocation.MyCommand.Name): parameter -Directory has been specified, but is replaced by by parent folder of -JobChain parameter"
                }
                $Directory = Get-JobSchedulerObject-Parent $JobChain
            } else { # job chain name includes no directory
                $JobChain = $Directory + '/' + $JobChain
            }
        }
        
        if ( $Order )
        {
            if ( (Get-JobSchedulerObject-Basename $Order) -ne $Order ) # order name includes a directory
            {
                if ( $Directory -ne '/' )
                {
                    # Write-Warning "$($MyInvocation.MyCommand.Name): parameter -Directory has been specified, but is replaced by by parent folder of -Order parameter"
                }
                $Directory = Get-JobSchedulerObject-Parent $Order
            } else { # order name includes no directory
                # $Order = $Directory + '/' + $Order
            }
        }
    
        if ( $FromDate )
        {
            $from = "from='" + (Get-Date $FromDate -Format u).Replace(' ', 'T') + "'"
        } else {
            $from = "from='" + (Get-Date -Format u).Replace(' ', 'T') + "'"
        }
        
        if ( $ToDate )
        {
            $before = "before='" + (Get-Date $ToDate -Format u).Replace(' ', 'T') + "'"
        } elseif ( $FromDate ) {
            $before = "before='" + (Get-Date (Get-Date $FromDate).AddDays($Days) -Format u).Replace(' ', 'T') + "'"
        } else {
            $before = "before='" + (Get-Date (Get-Date).AddDays($Days) -Format u).Replace(' ', 'T') + "'"
        }
        
        if ( $Days -ge 1 -and $Limit -eq 100 )
        {
            $Limit = $Limit*$Days
        }
        
        $command = "<show_calendar what='orders' limit='$($Limit)' $($from) $($before)/>"
        Write-Debug ".. $($MyInvocation.MyCommand.Name):  sending command to JobScheduler $($js.Url)"
        Write-Debug ".. $($MyInvocation.MyCommand.Name):  sending command: $command"
        
        $calXml = Send-JobSchedulerXMLCommand $js.Url $command
        if ( $calXml )
        {           
            $cal = Create-CalendarObject

            if ( $JobChain -or $Order -or !$Job )
            {
                $output = ''
                $xPath = '/spooler/answer/calendar/at'
                
                if ( $Order -and $JobChain )
                {
                    $xPath += "[@order='$($Order)' and @job_chain='$($JobChain)']"
                } elseif ( $JobChain ) {
                    $xPath += "[@job_chain='$($JobChain)']"
                } elseif ( $Directory ) {
                    $xPath += "[starts-with(@job_chain, '$($Directory)')]"
                }
                
                Write-Debug ".. $($MyInvocation.MyCommand.Name):  applying xPath for orders by start time: $xPath"
                $calAtOrders = Select-XML -XML $calXml -Xpath $xPath
                foreach( $calAtOrder in $calAtOrders )
                {
                    $atOrder = Create-CalendarAtOrderObject
                    $atOrder.JobChain = $calAtOrder.Node.job_chain
                    $atOrder.OrderId = $calAtOrder.Node.order
                    $atOrder.StartAt = $calAtOrder.Node.at
                    $cal.AtOrder += $atOrder
                    
                    if ( $Display )
                    {
                        $output += "
at $($atOrder.StartAt) order $($atOrder.OrderId) job chain $($atOrder.JobChain)
"
                    }
                }
            
                if ( $Display -and $output )
                {
                    $output = "
________________________________________________________________________
Orders by start-time
" + $output
                    Write-Output $output
                }

                $output = ''
                $xPath = '/spooler/answer/calendar/period'
                
                if ( $Order -and $JobChain )
                {
                    $xPath += "[@order='$($Order)' and @job_chain='$($JobChain)']"
                } elseif ( $JobChain ) {
                    $xPath += "[@job_chain='$($JobChain)']"
                } elseif ( $Directory ) {
                    $xPath += "[starts-with(@job_chain, '$($Directory)')]"
                } else {
                    $xPath += '[@order]'
                }
                
                Write-Debug ".. $($MyInvocation.MyCommand.Name):  applying xPath for orders by repeat interval: $xPath"
                $calPeriodOrders = Select-XML -XML $calXml -Xpath $xPath
                foreach( $calPeriodOrder in $calPeriodOrders )
                {
                    $periodOrder = Create-CalendarPeriodOrderObject
                    $periodOrder.JobChain = $calPeriodOrder.Node.job_chain
                    $periodOrder.OrderId = $calPeriodOrder.Node.order
                    $periodOrder.BeginAt = $calPeriodOrder.Node.begin
                    $periodOrder.EndAt = $calPeriodOrder.Node.end
                    $periodOrder.Repeat = $calPeriodOrder.Node.repeat
                    $periodOrder.AbsoluteRepeat = $calPeriodOrder.Node.absolute_repeat
                    $cal.PeriodOrder += $periodOrder
                    
                    if ( $Display )
                    {
                        $output += "
begin at $($periodOrder.BeginAt) end at $($periodOrder.EndAt) repeat $($periodOrder.Repeat) absolute repeat $($periodOrder.AbsoluteRepeat) order $($periodOrder.OrderId) job chain $($periodOrder.JobChain)
"
                    }
                }

                if ( $Display -and $output )
                {
                    $output = "
________________________________________________________________________
Orders by repeat interval
" + $output
                    Write-Output $output
                }
            }
            
            if ( $Job -or ( !$JobChain -and !$Order ) )
            {
                $output = ''
                $xPath = '/spooler/answer/calendar/period'

                if ( $Job )
                {
                    $xPath += "[@job='$($Job)']"
                } elseif ( $Directory ) {
                    $xPath += "[starts-with(@job, '$($Directory)')]"
                } else {
                    $xPath += '[@job]'
                }
                
                Write-Debug ".. $($MyInvocation.MyCommand.Name):  applying xPath for jobs by repeat interval: $xPath"
                $calPeriodJobs = Select-XML -XML $calXml -Xpath $xPath
                foreach( $calPeriodJob in $calPeriodJobs )
                {
                    $periodJob = Create-CalendarPeriodJobObject
                    $periodJob.Job = $calPeriodJob.Node.job
                    $periodJob.BeginAt = $calPeriodJob.Node.begin
                    $periodJob.EndAt = $calPeriodJob.Node.end
                    $periodJob.Repeat = $calPeriodJob.Node.repeat
                    $periodJob.AbsoluteRepeat = $calPeriodJob.Node.absolute_repeat
                    $cal.PeriodJob += $periodJob
    
                    if ( $Display )
                    {
                        $output += "
begin at $($periodJob.BeginAt) end at $($periodJob.EndAt) repeat $($periodJob.Repeat) absolute repeat $($periodJob.AbsoluteRepeat) job $($periodJob.Job)
"
                    }
                }

                if ( $Display -and $output )
                {
                    $output = "
________________________________________________________________________
Jobs by repeat interval
" + $output
                    Write-Output $output
                }

                if ( !$NoOutputs )
                {
                    $cal
                }
            }
        }
    }

    End
    {
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
