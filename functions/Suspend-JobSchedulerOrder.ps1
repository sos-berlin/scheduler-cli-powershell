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

.PARAMETER Directory
Optionally specifies the folder where the job chain is located. The directory is determined
from the root folder, i.e. the "live" directory.

If the -JobChain parameter specifies the name of job chain then the location specified from the 
-Directory parameter is added to the job chain location.

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
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/'
)
	Begin
	{
		Approve-JobSchedulerCommand $MyInvocation.MyCommand

        $parameters = @()
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
                $Directory = Get-JobSchedulerObject-Parent $JobChain
            } else { # job chain name includes no directory
                $JobChain = $Directory + '/' + $JobChain
            }
        }

        $suspendOrder = Create-OrderObject
        $suspendOrder.Order = $Order
        $suspendOrder.JobChain = Get-JobSchedulerObject-Basename $JobChain
        $suspendOrder.Name = $suspendOrder.JobChain + ',' + $suspendOrder.Order
		$suspendOrder.Directory = Get-JobSchedulerObject-Parent $JobChain
		$suspendOrder.Path = $suspendOrder.Directory + '/' + $suspendOrder.Name
		# output objects are created by Update-JobSchedulerOrder
		# $suspendOrder
        $parameters += $suspendOrder
    }

    End
    {
        $parameters | Update-JobSchedulerOrder -Action suspend
    }
}

Set-Alias -Name Suspend-Order -Value Suspend-JobSchedulerOrder
Set-Alias -Name Stop-Order -Value Suspend-JobSchedulerOrder
Set-Alias -Name Stop-JobSchedulerOrder -Value Suspend-JobSchedulerOrder
