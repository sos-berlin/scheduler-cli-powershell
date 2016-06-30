function Get-JobSchedulerSingleOrder
{
<#
.SYNOPSIS
Returns an individual order from the JobScheduler Master.

.DESCRIPTION
Returns as single order independently from the fact that it is active in the JobScheduler Master
or is a past order, e.g. a completed ad hoc order.

The order is selected from a JobScheduler Master

* by the job chain that is assigned to an order and
* by an the order identification of an individual order.

.PARAMETER Directory
Optionally specifies the folder where the job chain is located. The directory is determined
from the root folder, i.e. the "live" directory.

If the -JobChain parameter specifies the name of job chain then the location specified from the 
-Directory parameter is added to the job chain location.

.PARAMETER JobChain
Specifies the path and name of a job chain for which the order should be returned.
The -JobChain parameter is assumed to include the full path and name of the job chain.

With the -Directory parameter being used the job chain is assumed to be located in that directory.

.PARAMETER Order
Specifies the path and name of an order that should be returned.

* For permanent orders either 
** the name of an order is specified then the -JobChain parameter is used to determine the folder.
** or the full path is specified for the order.
* For ad hoc orders the name of the order is specified without a path.

.PARAMETER WithLog
Specifies the order log to be returned. 

This operation is time-consuming and should be restricted to selecting individual orders.

.OUTPUTS
This cmdlet returns an a single order object.

.EXAMPLE
$order = Get-SingleOrder -JobChain /sos/reporting/Reporting -Order facts

Returns the order with the specified name from the specified job chain.

.EXAMPLE
$order = Get-SingleOrder -JobChain /sos/reporting/Reporting -Order facts -WithLog

Returns the order with the specified name from the specified job chain and the log output of the last order run.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Order,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $WithLog
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch
    }
    
    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter JobChain=$($JobChain), Order=$($Order), WithLog=$($WithLog)"
    
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
            if ( (Get-JobSchedulerObject-Basename $JobChain) -eq $JobChain ) # job chain path includes no directory
            {
                if ( $Directory -eq '/' )
                {
                    $JobChain = $Directory + $JobChain
                } else {
                    $JobChain = $Directory + '/' + $JobChain
                }
            }
        }

        $orderAttributes = if ( $WithLog ) { " what='log'" } else { '' }
        $command = "<show_order order='$($Order)' job_chain='$($JobChain)' $($orderAttributes)/>"
    
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Url)"
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): sending request: $command"
        
        $orderXml = Send-JobSchedulerXMLCommand $js.Url $command
        if ( $orderXml )
        {    
            $orderNodes = Select-XML -XML $orderXml -Xpath '/spooler/answer/order'
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): selection of permanent orders: /spooler/answer/order"

            foreach( $orderNode in $orderNodes )
            {
                if ( !$orderNode.Node.id )
                {
                    continue
                }
        
                $o = Create-OrderObject
                $o.Order = $orderNode.Node.id
                $o.Name = $orderNode.Node.order
                $o.Path = $orderNode.Node.path
                $o.Directory = Get-JobSchedulerObject-Parent $orderNode.Node.path
                $o.JobChain = $JobChain
                $o.State = $orderNode.Node.state
                $o.StateText = $orderNode.Node.state_text
                
                if ( $WithLog )
                {
                   $o.Log = (Select-XML -XML $orderXml -Xpath '//spooler/answer/order/log').Node."#text"
                }
                
                $o
            }
            
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): order found"
        }
    }

    End
    {
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
    
}

Set-Alias -Name Get-SingleOrder -Value Get-JobSchedulerSingleOrder
