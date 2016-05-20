function Suspend-JobSchedulerOrder
{
<#
.SYNOPSIS
Suspends a number of orders in the JobScheduler Master.

.DESCRIPTION
This cmdlet is an alias for Update-Order -Action "suspend"

.PARAMETER Order
Specifies the identifier of an order.

Both parameters -Order and -JobChain have to be specified if no pipelined order objects are used.

.PARAMETER JobChain
Specifies the path and name of a job chain for which orders should be suspended.

Both parameters -Order and -JobChain have to be specified if no pipelined order objects are used.

.INPUTS
This cmdlet accepts pipelined order objects that are e.g. returned from a Get-Order cmdlet.

.OUTPUTS
This cmdlet returns an array of order objects.

.EXAMPLE
Suspend-Order -Order Reporting -JobChain /sos/reporting/Reporting

Suspends the order "Reporting" from the specified job chain.

.EXAMPLE
Get-Order | Suspend-Order

Suspends all orders for all job chains.

.EXAMPLE
Get-Order -Directory / -NoSubfolders | Suspend-Order

Suspends orders that are configured with the root folder ("live" directory)
without consideration of subfolders.

.EXAMPLE
Get-Order -JobChain /test/globals/chain1 | Suspend-Order

Suspends all orders for the specified job chain.

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
		Approve-JobSchedulerCommand $MyInvocation.MyCommand

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
        $parameters | Update-JobSchedulerOrder -Action suspend
    }
}

Set-Alias -Name Suspend-Order -Value Suspend-JobSchedulerOrder
Set-Alias -Name Stop-Order -Value Suspend-JobSchedulerOrder
Set-Alias -Name Stop-JobSchedulerOrder -Value Suspend-JobSchedulerOrder
