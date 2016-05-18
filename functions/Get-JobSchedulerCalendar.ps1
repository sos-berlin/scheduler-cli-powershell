function Get-JobSchedulerCalendar
{
<#
.SYNOPSIS
Shows the next start dates for jobs and orders of JobScheduler Master.

.DESCRIPTION
The next start date for jobs and orders is calculated by JobScheduler Master.
This cmdlet returns a list of start date objects that indicate the next start time.

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
$startDates = Get-Calendar

Returns start dates for the next 24 hrs.

.EXAMPLE
$startDates = Get-Calendar -Days 3

Returns the start dates for the next 3 days.

.EXAMPLE
$startDates = Get-Calendar -FromDate 2016-06-01 -ToDate 2016-06-30

Returns the start dates between the specified dates.

.EXAMPLE
Get-Calendar -Display

Displays formatted output.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
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
    Process
    {
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
        
        $command = "<show_calendar what='orders' $($from) $($before)/>"
        Write-Debug ". $($MyInvocation.MyCommand.Name):  sending command to JobScheduler $($js.Hostname):$($js.Port)"
        Write-Debug ". $($MyInvocation.MyCommand.Name):  sending command: $command"
        
        $calXml = Send-JobSchedulerXMLCommand $js.Hostname $js.Port $command
        if ( $calXml )
        {            
            $cal = Create-CalendarObject

            $output = ""
            $calAtOrders = Select-XML -XML $calXml -Xpath "/spooler/answer/calendar/at"
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
at $($atOrder.StartAt) oder $($atOrder.OrderId) job chain $($atOrder.JobChain)
"
                }
            }
            
            if ( $Display -and $output )
            {
                $output = "
________________________________________________________________________
Orders by start-time
" + $output
                Write-Host $output
            }


            $output = ""
            $calPeriodOrders = Select-XML -XML $calXml -Xpath "/spooler/answer/calendar/period[@order]"
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
                Write-Host $output
            }
            
            
            $output = ""
            $calPeriodJobs = Select-XML -XML $calXml -Xpath "/spooler/answer/calendar/period[@job]"
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
                Write-Host $output
            }

            if ( !$NoOutputs )
            {
                $cal
            }
        }
    }
}

Set-Alias -Name Get-Calendar -Value Get-JobSchedulerCalendar
