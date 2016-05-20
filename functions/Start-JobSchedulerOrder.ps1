function Start-JobSchedulerOrder
{
<#
.SYNOPSIS
Resets a number of orders in the JobScheduler Master.

.DESCRIPTION
This cmdlet is an alias for Update-Order -Action reset

.PARAMETER Order
Specifies the identifier of an order.

Both parameters -Order and -JobChain have to be specified if no pipelined order objects are used.

.PARAMETER JobChain
Specifies the path and name of a job chain for which orders should be reset.

Both parameters -Order and -JobChain have to be specified if no pipelined order objects are used.

.PARAMETER Parameters
Specifies the parameters for the order. Parameters are created from a hashmap,
i.e. a list of names and values.

.PARAMETER Title
Specifies the title of the order.

.PARAMETER At
Specifies the point in time when the order should start:

* now
** specifies that the order should start immediately
* now+1800
** specifies that the order should start with a delay of 1800 seconds, i.e. 30 minutes later.
* yyyy-mm-dd HH:MM[:SS]
** specifies that the order should start at the specified point in time.

.PARAMETER State
Specifies that the order should enter the job chain at the job chain node that
is assigend the specified state.

.PARAMETER EndState
Specifies that the order should leave the job chain at the job chain node that
is assigend the specified state.

.INPUTS
This cmdlet accepts pipelined order objects that are e.g. returned from a Get-Order cmdlet.

.OUTPUTS
This cmdlet returns an array of order objects.

.EXAMPLE
Reset-Order -Order Reporting -JobChain /sos/reporting/Reporting

Resets the order "Reporting" from the specified job chain.

.EXAMPLE
Get-Order | Reset-Order

Resets all orders for all job chains.

.EXAMPLE
Get-Order -Directory / -NoSubfolders | Reset-Order

Resets orders that are configured with the root folder ("live" directory)
without consideration of subfolders.

.EXAMPLE
Get-Order -JobChain /test/globals/chain1 | Reset-Order

Resets all orders for the specified job chain.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Order,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $Parameters,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Title,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $At = 'now',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $State,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $EndState
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand

        $startOrders = @()
    }
    
    Process
    {
        $o = Create-OrderObject
        $o.Order = $Order
        $o.JobChain = $JobChain
        $o.Parameters = $Parameters
        $o.Title = $Title
        $o.At = $At
        $o.State = $State
        $o.EndState = $EndState
        $startOrders += $o
    }

    End
    {
        $startOrders | Update-JobSchedulerOrder -Action start -At $At
    }
}

Set-Alias -Name Start-Order -Value Start-JobSchedulerOrder
