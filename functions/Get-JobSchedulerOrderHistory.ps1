function Get-JobSchedulerOrderHistory
{
<#
.SYNOPSIS
Returns a number of JobScheduler history entries for orders.

.DESCRIPTION
Order history entries are returned independently from the fact that the order is present in the JobScheduler Master.
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

.PARAMETER MaxHistoryEntries
Specifies the number of entries that are returned from the history. Entries are provided
in descending order starting with the latest history entry.

Default: 1

.PARAMETER WithLog
Specifies the order log to be returned. 

This operation is time-consuming and should be restricted to selecting individual orders.

.OUTPUTS
This cmdlet returns an array of order objects.

.EXAMPLE
$history = Get-JobSchedulerOrderHistory -JobChain /test/globals/chain1

Returns the latest history entry for job chain "chain1" from the folder "/test/globals".

.EXAMPLE
$history = Get-JobSchedulerOrderHistory -JobChain /test/globals/chain1 -Order order1

Returns the latest history entry order "order1" from the folder "/test/globals" with the job chain "chain1".

.EXAMPLE
$history = Get-JobSchedulerOrderHistory -JobChain /test/globals/chain1 -MaxHistoryEntries 5

Returns the 5 latest history entries for the specified job chain and includes the log output.

.EXAMPLE
$history = Get-JobSchedulerOrderHistory -JobChain /test/globals/chain1 -WithLog

Returns the 5 latest history entries for the specified job chain and includes the log output.

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
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $MaxHistoryEntries = 1,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $WithLog
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch

        $orderHistoryCount = 0
    }
        
    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, JobChain=$JobChain, Order=$Order, WithLog=$WithLog"
    
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

        if ( $WithLog )
        {
            $whatWithLog = ' log'
        } else {
            $whatWithLog = ''
        }
                
        $command = "<show_job_chain job_chain='$($JobChain)' what='order_history$($whatWithLog)' max_order_history='$($MaxHistoryEntries)'/>"        

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
        
                $o = Create-OrderHistoryObject
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

#                not available from <show_job_chain>
#                $o.Log = $orderNode.Node.log."#text"

                if ( $WithLog )
                {
                    $command = "<show_order history_id='$($orderNode.Node.history_id)' job_chain='$($o.JobChain)' what='log'/>"
                    Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Url)"
                    Write-Debug ".. $($MyInvocation.MyCommand.Name): sending request: $command"
                    
                    $orderLogXml = Send-JobSchedulerXMLCommand $js.Url $command
                    if ( $orderLogXml )
                    {
                        $o.Log = (Select-XML -XML $orderLogXml -Xpath '//spooler/answer/order/log').Node."#text"
                    }
                }

                $o
                $orderHistoryCount++
            }            
        }
    }

    End
    {
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): $orderHistoryCount order history entries found"
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
