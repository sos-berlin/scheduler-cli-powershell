function Get-JobSchedulerOrder
{
<#
.SYNOPSIS
Returns a number of orders from the JobScheduler Master.

.DESCRIPTION
Orders are selected from a JobScheduler Master

* by the folder of the order location including subfolders
* by the job chain that is assigned to an order
* by an individual order.

Resulting orders can be forwarded to other cmdlets for pipelined bulk operations.

.PARAMETER Directory
Optionally specifies the folder for which orders should be returned. The directory is determined
from the root folder, i.e. the "live" directory.

One of the parameters -Directory, -JobChain or -Order has to be specified if no pipelined order objects are provided.

.PARAMETER JobChain
Optionally specifies the path and name of a job chain for which orders should be returned.
If the name of a job chain is specified then the -Directory parameter is used to determine the folder.
Otherwise the -JobChain parameter is assumed to include the full path and name of the job chain.

One of the parameters -Directory, -JobChain or -Order has to be specified if no pipelined order objects are provided.

.PARAMETER Order
Optionally specifies the path and name of an order that should be returned.
If the name of an order is specified then the -Directory parameter is used to determine the folder.
Otherwise the -Order parameter is assumed to include the full path and name of the order.

One of the parameters -Directory, -JobChain or -Order has to be specified if no pipelined order objects are provided.

.PARAMETER NoSubfolders
Specifies that no subfolders should be looked up. By default any subfolders will be searched for orders.

.PARAMETER NoPermanent
Specifies that no permanent orders should be looked up but instead ad hoc orders only. 
By default only permanent orders will be looked up.

.OUTPUTS
This cmdlet returns an array of order objects.

.EXAMPLE
$orders = Get-Order

Returns all orders.

.EXAMPLE
$orders = Get-Order -Directory / -NoSubfolders

Returns all orders that are configured with the root folder ("live" directory)
without consideration of subfolders.

.EXAMPLE
$orders = Get-Order -JobChain /test/globals/chain1

Returns the orders for job chain chain1 from the folder "/test/globals".

.EXAMPLE
$orders = Get-Order -Order /test/globals/order1

Returns the order order1 from the folder "/test/globals".

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Order,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $NoSubfolders,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $NoPermanent
)
    Begin
    {
    }        
        
    Process
    {
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, JobChain=$JobChain, Order=$Order"
    
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
                if ( $Directory -ne '/' )
                {
                    # Write-Warning "$($MyInvocation.MyCommand.Name): parameter -Directory has been specified, but is replaced by by parent folder of -JobChain parameter"
                }
                $Directory = Get-JobSchedulerObject-Parent $JobChain
            } else { # job chain name includes no directory
                $JobChain = $Directory + '/' + $JobChain
            }
        }
        
        if ( $Order )
        {
            if ( (Get-JobSchedulerObject-Basename $Order) -ne $Order ) # order name includes a directory
            {
                if ( $Directory -ne '/' )
                {
                    # Write-Warning "$($MyInvocation.MyCommand.Name): parameter -Directory has been specified, but is replaced by by parent folder of -Order parameter"
                }
                $Directory = Get-JobSchedulerObject-Parent $Order
            } else { # order name includes no directory
                $Order = $Directory + '/' + $Order
            }
        }
        
        $whatNoSubfolders = if ( $NoSubfolders ) { " no_subfolders" } else { "" }
        $command = "<show_state subsystems='folder order' what='folders job_chain_orders$($whatNoSubfolders)' path='$($Directory)'/>"
    
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Hostname):$($js.Port)"
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): sending request: $command"
        
        $orderXml = Send-JobSchedulerXMLCommand $js.Hostname $js.Port $command
        if ( $orderXml )
        {    
            $orderCount = 0

            if ( $Order )
            {
                if ( $NoPermanent )
                {
                    if ( $JobChain )
                    {
                        $orderNodes = Select-XML -XML $orderXml -Xpath "//folder/job_chains/job_chain[@path = '$($JobChain)']/job_chain_node/order_queue/order[@path = '/']"
                        Write-Verbose ".. $($MyInvocation.MyCommand.Name): selection of ad hoc orders for order and job chain: //folder/job_chains/job_chain[@path = '$($JobChain)']/job_chain_node/order_queue/order[@path = '/']"
                    } else {
                        $orderId = Get-JobSchedulerObjectBasename $Order
                        $orderNodes = Select-XML -XML $orderXml -Xpath "//folder/job_chains/job_chain/job_chain_node/order_queue/order[@order = '$($orderId)' and @path = '/']"
                        Write-Verbose ".. $($MyInvocation.MyCommand.Name): selection of ad hoc orders for order without job chain: //folder/job_chains/job_chain/job_chain_node/order_queue/order[@order = '$($orderId)' and @path = '/']"
                    }
                } else {
                    $orderNodes = Select-XML -XML $orderXml -Xpath "//folder/job_chains/job_chain/job_chain_node/order_queue/order[@path = '$($Order)']"
                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): selection of permanent orders for order: //folder/job_chains/job_chain/job_chain_node/order_queue/order[@path = '$($Order)']"
                }
            } elseif ( $JobChain ) {
                if ( $NoPermanent )
                {
                    $orderNodes = Select-XML -XML $orderXml -Xpath "//folder/job_chains/job_chain[@path = '$($JobChain)']/job_chain_node/order_queue/order[@path = '/']"
                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): selection of ad hoc orders by job chain: //folder/job_chains/job_chain[@path = '$($JobChain)']/job_chain_node/order_queue/order[@path = '/']"
                } else {
                    $orderNodes = Select-XML -XML $orderXml -Xpath "//folder/job_chains/job_chain[@path = '$($JobChain)']/job_chain_node/order_queue/order"
                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): selection of permanent orders by job chain: //folder/job_chains/job_chain[@path = '$($JobChain)']/job_chain_node/order_queue/order"
                }
            } else {
                if ( $NoPermanent )
                {
                    $orderNodes = Select-XML -XML $orderXml -Xpath "//folder/job_chains/job_chain/job_chain_node/order_queue/order[@path = '/']"
                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): selection of ad hoc orders: //folder/job_chains/job_chain/job_chain_node/order_queue/order[@path = '/']"
                } else {
                    $orderNodes = Select-XML -XML $orderXml -Xpath "//folder/job_chains/job_chain/job_chain_node/order_queue/order[not(@path = '/')]"
                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): selection of permanent orders: //folder/job_chains/job_chain/job_chain_node/order_queue/order[not(@path = '/')]"
                }
            }

            foreach( $orderNode in $orderNodes )
            {
                if ( !$orderNode.Node.name )
                {
                    continue
                }
        
                $o = Create-OrderObject
                $o.Order = $orderNode.Node.id
                $o.Name = $orderNode.Node.name
                $o.Path = $orderNode.Node.path
                $o.Directory = Get-JobSchedulerObject-Parent $orderNode.Node.path
                $o.JobChain = $orderNode.Node.SelectSingleNode("../../../@path")."#text"
                $o.State = $orderNode.Node.state
                $o.Title = $orderNode.Node.title
                $o.LogFile = $orderNode.Node.log_file
                $o.Job = $orderNode.Node.job
                $o.NextStartTime = $orderNode.Node.next_start_time
                $o.StateText = $orderNode.Node.state_text
                $o
                $orderCount++
            }
            
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $orderCount orders found"
        }
    }
}

Set-Alias -Name Get-Order -Value Get-JobSchedulerOrder
