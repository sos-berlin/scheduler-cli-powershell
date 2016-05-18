function Reset-JobSchedulerOrder
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
    [string] $JobChain
)
    Begin
    {
        $parameters = @()
    }
    
    Process
    {
        $o = Create-OrderObject
        $o.Order = $Order
        $o.JobChain = $JobChain
        $parameters += $o
    }

    End
    {
        $parameters | Update-JobSchedulerOrder -Action reset
    }
}

Set-Alias -Name Reset-Order -Value Reset-JobSchedulerOrder
