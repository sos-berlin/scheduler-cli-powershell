function Get-JobSchedulerOrderHistory
{
<#
.SYNOPSIS
ReturnsJobScheduler history items for orders.

.DESCRIPTION
This cmdlet is deprecated as it is an alias for the Get-JobSchedulerOrder cmdlet that
offers the same functionality when used with the -WithHistory switch. Therefore the 
same functionality applies to both cmdlets.

Order history items are returned independently from the fact that the order is present in the JobScheduler Master.
This includes temporary ad hoc orders to be returned that are completed and not active
with a Master.

Orders are selected from a JobScheduler Master

* by the job chain that an order is assigned.
* by a specific order.

Resulting orders can be forwarded to other cmdlets for pipelined bulk operations.

.PARAMETER OrderId
Optionally specifies the path and name of an order for which the history should be returned.
If the ID of an order is specified then the -Directory parameter is used to determine the folder.
Otherwise the -OrderId parameter is assumed to include the full path and ID of the order.

.PARAMETER JobChain
Specifies the path and name of a job chain for which order history items should be returned.
If the name of a job chain is specified then the -Directory parameter is used to determine the folder.
Otherwise the -JobChain parameter is assumed to include the full path and name of the job chain.

.PARAMETER Directory
Optionally specifies the folder for which order history items should be returned. The directory is determined
from the root folder, i.e. the "live" directory.

.PARAMETER Recursive
Specifies that any sub-folders should be looked up if the -Directory parameter is used.

.PARAMETER Compact
Specifies that fewer order history attributes will be returned.

.PARAMETER WithLog
Specifies the order log to be returned. 

This operation is time-consuming and should be restricted to selecting individual orders.

.PARAMETER MaxLastHistoryItems
Specifies the number of items that should be returned from the history. Items are provided
in descending order starting with the latest history entry.

Default: 1

.OUTPUTS
This cmdlet returns an array of history objects.

.EXAMPLE
$history = Get-JobSchedulerOrderHistory -JobChain /test/globals/chain1

Returns the latest history item for job chain "chain1" from the folder "/test/globals".

.EXAMPLE
$history = Get-JobSchedulerOrderHistory -JobChain /test/globals/chain1 -OrderId order1

Returns the latest history item for order "order1" from the folder "/test/globals" with the job chain "chain1".

.EXAMPLE
$history = Get-JobSchedulerOrderHistory -JobChain /test/globals/chain1 -MaxLastHistoryItems 5

Returns the 5 latest history items for the specified job chain and includes the log output.

.EXAMPLE
$history = Get-JobSchedulerOrderHistory -JobChain /test/globals/chain1 -WithLog

Returns the latest history item for the specified job chain and includes the log output.

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
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Recursive,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Compact,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $WithLog,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $MaxLastHistoryItems = 1
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
    }
        
    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, JobChain=$JobChain, Order=$Order, WithLog=$WithLog"

        Get-JobSchedulerOrder -OrderId $OrderId -JobChain $JobChain -Directory $Directory -Recursive:$Recursive -Compact:$Compact -WithLog:$WithLog -MaxLastHistoryItems $MaxLastHistoryItems -WithHistory
    }

    End
    {
    }
}
