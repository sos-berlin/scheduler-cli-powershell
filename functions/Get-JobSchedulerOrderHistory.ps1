function Get-JobSchedulerOrderHistory
{
<#
.SYNOPSIS
Returns a number of orders from the JobScheduler history.

.DESCRIPTION
Orders are returned independently from the fact if they are present in the JobScheduler Master.
This includes temporary ad hoc orders to be returned that are completed and not active
with a Master.

Orders are selected from a JobScheduler Master

* by the job chain that is assigned to an order
* by an individual order.

Resulting orders can be forwarded to other cmdlets for pipelined bulk operations.

.PARAMETER Directory
Optionally specifies the folder for which orders should be returned. The directory is determined
from the root folder, i.e. the "live" directory.

.PARAMETER JobChain
Specifies the path and name of a job chain for which orders should be returned.
If the name of a job chain is specified then the -Directory parameter is used to determine the folder.
Otherwise the -JobChain parameter is assumed to include the full path and name of the job chain.

.PARAMETER Order
Optionally specifies the path and name of an order that should be returned.
If the name of an order is specified then the -Directory parameter is used to determine the folder.
Otherwise the -Order parameter is assumed to include the full path and name of the order.

.PARAMETER WithLog
Specifies the order log to be returned. 

This operation is time-consuming and should be restricted to selecting individual orders.

.OUTPUTS
This cmdlet returns an array of order objects.

.EXAMPLE
$orders = Get-JobSchedulerOrderHistory -JobChain /test/globals/chain1

Returns the orders for job chain "chain1" from the folder "/test/globals".

.EXAMPLE
$orders = Get-JobSchedulerOrderHistory -JobChain /test/globals/chain1 -Order order1

Returns the order "order1" from the folder "/test/globals" with the job chain "chain1".

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Order,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $WithLog
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch

        $orderCount = 0
    }
        
    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, JobChain=$JobChain, Order=$Order, WithLog=$WithLog"
    
        if ( !$Directory -and !$JobChain -and !$Order )
        {
            throw "$($MyInvocation.MyCommand.Name): no directory, no job chain or order specified, use -Directory or -JobChain  or -Order"
        }

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
                if ( $Directory -eq '/' )
                {
                    $JobChain = $Directory + $JobChain
                } else {
                    $JobChain = $Directory + '/' + $JobChain
                }
            }
        }
        
        if ( $Order )
        {
            if ( (Get-JobSchedulerObject-Basename $Order) -ne $Order ) # order name includes a directory
            {
                $Directory = Get-JobSchedulerObject-Parent $Order
            } else { # order name includes no directory
                if ( $Directory -eq '/' )
                {
                    $Order = $Directory + $Order
                } else {
                    $Order = $Directory + '/' + $Order
                }
            }
        }

        $xPath = '//order_history/order['
        $and = ''

        if ( $JobChain )
        {
            $xPathJobChain = if ( $JobChain.StartsWith('/') ) { $JobChain.Substring( 1 ) } else { $JobChain }
            $xPath += "$($and)@job_chain='$($xPathJobChain)'"
            $and = ' and '
        }

        if ( $Order )
        {
            $orderId = Get-JobSchedulerObject-Basename $Order
            $xPath += "$($and)@id = '$($OrderId)'"
            Write-Debug ".. $($MyInvocation.MyCommand.Name): selection of orders for order: $xPath"
        }
        
        $xPath += ']'

        $command = "<show_job_chain job_chain='$($JobChain)' what='order_history' max_orders='10'/>"        

        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Url)"
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending request: $command"

        $orderXml = Send-JobSchedulerXMLCommand $js.Url $command

        Write-Debug ".. $($MyInvocation.MyCommand.Name): using XPath: $($xPath)"
        $orderNodes = Select-XML -XML $orderXml -Xpath $xPath

        if ( $orderNodes )
        {    
            foreach( $orderNode in $orderNodes )
            {
                if ( !$orderNode.Node.name )
                {
                    continue
                }
        
                $o = Create-OrderObject
                $o.Order = $orderNode.Node.id
                $o.Name = $orderNode.Node.id
                $o.Path = $orderNode.Node.path
                $o.Directory = Get-JobSchedulerObject-Parent $orderNode.Node.path
                $o.JobChain = $orderNode.Node.job_chain
                $o.State = $orderNode.Node.state
                $o.Title = $orderNode.Node.title
                $o.Job = $orderNode.Node.job
                $o.NextStartTime = $orderNode.Node.next_start_time
                $o.StartTime = $orderNode.Node.start_time
                $o.EndTime = $orderNode.Node.end_time
                $o.StateText = $orderNode.Node.state_text
                $o.HistoryId = $orderNode.Node.history_id
                
                $o
                $orderCount++
            }            
        }
    }

    End
    {
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): $orderCount orders found"
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
