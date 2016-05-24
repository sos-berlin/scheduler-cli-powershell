function Start-JobSchedulerOrder
{
<#
.SYNOPSIS
Starts an order for a job chain in the JobScheduler Master.

.DESCRIPTION
Start an existing order for a job chain.

.PARAMETER JobChain
Specifies the path and name of a job chain for which orders should be started.

.PARAMETER Order
Optionally specifies the identifier of an order.

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

Default: now

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
Start-Order -JobChain /sos/reporting/Reporting

Starts an order of the specified job chain.

.EXAMPLE
Start-Order -Order 123 -JobChain /sos/reporting/Reporting

Starts the order "123" of the specified job chain.

.EXAMPLE
Start-Order -Order 123 -JobChain /sos/reporting/Reporting -At "now+1800"

Starts the specified order.

.EXAMPLE
Start-Order -JobChain /sos/reporting/Reporting -Order 548 -At "now+3600" -Parameters @{'param1'='value1'; 'param2'='value2'}

Starts an order of the specified job chain. The order will start one hour later and will use the
parameters from the specified hashmap.

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
