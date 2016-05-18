function Show-JobSchedulerCalendar
{
<#
.SYNOPSIS
Shows next start dates for jobs and orders of JobScheduler Master.

.DESCRIPTION
This cmdlet is an alias for Get-Calendar -Display -NoOutputs

.PARAMETER Days
Optionally specifies the number of days starting from the current time for which
start dates are returned.

Default: 1

.PARAMETER FromDate
Optionally specifies the date starting from which start dates are calculated.

.PARAMETER ToDate
Optionally specifies the date for which the calculation of start dates ends.

.EXAMPLE
Show-Calendar

Shows start dates for the next 24 hrs.

.EXAMPLE
Show-Calendar -Days 3

Shows the start dates for the next 3 days.

.EXAMPLE
Show-Calendar -FromDate 2016-06-01 -ToDate 2016-06-30

Shows the start dates between the specified dates.

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
    [DateTime] $ToDate
)
    Process
    {
        $parameters = @{ "Days"=$Days; "FromDate"=$FromDate; "ToDate"=$ToDate }
        $arguments = New-Object System.Management.Automation.PSObject -Property $parameters
        $arguments | Get-JobSchedulerCalendar -Display -NoOutputs
    }
}

Set-Alias -Name Show-Calendar -Value Show-JobSchedulerCalendar
