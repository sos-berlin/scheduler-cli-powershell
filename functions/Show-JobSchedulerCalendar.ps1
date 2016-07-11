function Show-JobSchedulerCalendar
{
<#
.SYNOPSIS
Shows next start dates for jobs and orders of JobScheduler Master.

.DESCRIPTION
This cmdlet is an alias for Get-Calendar -Display -NoOutputs

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

.EXAMPLE
Show-JobSchedulerCalendar

Shows start dates for the next 24 hrs.

.EXAMPLE
Show-JobSchedulerCalendar -Days 3

Shows the start dates for the next 3 days.

.EXAMPLE
Show-JobSchedulerCalendar -FromDate 2016-06-01 -ToDate 2016-06-30

Shows the start dates between the specified dates.

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
    [DateTime] $ToDate
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
    }

    Process
    {
        $parameters = @{ 'Directory'=$Directory; 'JobChain'=$JobChain; 'Order'=$Order; 'Job'=$Job; 'Limit'=$Limit; 'Days'=$Days; 'FromDate'=$FromDate; 'ToDate'=$ToDate }
        $arguments = New-Object System.Management.Automation.PSObject -Property $parameters
        $arguments | Get-JobSchedulerCalendar -Display -NoOutputs
    }
}
