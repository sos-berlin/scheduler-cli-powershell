function Add-JobSchedulerOrder
{
<#
.SYNOPSIS
Adds an order to a job chain in the JobScheduler Master.

.DESCRIPTION
Creates a temporary ad hoc order for execution with the specified job chain

.PARAMETER JobChain
Specifies the path and name of a job chain for which orders should be added.

.PARAMETER Order
Optionally specifies the identifier of an order.

If no order identifier is specified then JobScheduler assigns a unique identifier.

.PARAMETER Directory
Optionally specifies the folder where the job chain is located. The directory is determined
from the root folder, i.e. the "live" directory.

If the -JobChain parameter specifies the name of job chain then the location specified from the 
-Directory parameter is added to the job chain location.

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

.PARAMETER Replace
Specifies that the order should replace an existing order with the same order identification.

.PARAMETER NoImmediate
Specifies that the order is not immediately submitted and that no order identification is returned 
with the order object. This parameter is intended for a situation when no order identification
is required when executing the cmdlet.

.INPUTS
This cmdlet accepts pipelined order objects that are e.g. returned from a Get-Order cmdlet.

.OUTPUTS
This cmdlet returns an array of order objects.

.EXAMPLE
Add-Order -JobChain /sos/reporting/Reporting

Adds an order to the specified job chain. The order identification is generated by the JobScheduler Master.

.EXAMPLE
1..10 | Add-Order -JobChain /sos/reporting/Reporting

Adds 10 orders to a job chain.

.EXAMPLE
Add-Order -Order 123 -JobChain /sos/reporting/Reporting

Adds the order "123" to the specified job chain.

.EXAMPLE
Add-Order -Order 123 -JobChain /sos/reporting/Reporting -At "now+1800" -Replace

Adds the specified order. Should the order exist then it will be replaced.

.EXAMPLE
Add-Order -JobChain /sos/reporting/Reporting -At "now+3600" -Parameters @{'param1'='value1'; 'param2'='value2'}

Adds an order to the specified job chain. The order will start one hour later and will use the
parameters from the specified hashmap.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Order,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $Parameters,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [string] $Title,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [string] $At = 'now',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [string] $State,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [string] $EndState,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Replace,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $NoImmediate
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch

        $command = ''
        $orderCount = 0
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
	
        if ( $Order )
        {
            if ( (Get-JobSchedulerObject-Basename $Order) -ne $Order ) # order id includes a directory
            {
                $Directory = Get-JobSchedulerObject-Parent $Order
				$Order = Get-JobSchedulerObject-Basename $Order
                $JobChain = $Directory + '/' + (Get-JobSchedulerObject-Basename $JobChain)
            }
        }
	
        $orderAttributes = ''

        if ( !$NoImmediate )
        {
            $command = ''
        }

        if ( $Order )
        {
            $orderAttributes += " id='$($Order)'"
        }
        
        if ( $Title )
        {
            $orderAttributes += " title='$($Title)'"
        }
        
        if ( $At )
        {
            $orderAttributes += " at='$($At)'"
        }
        
        if ( $State )
        {
            $orderAttributes += " state='$($State)'"
        }
        
        if ( $EndState )
        {
            $orderAttributes += " end_state='$($EndState)'"
        }
        
        if ( $Replace )
        {
            $orderAttributes += " replace='yes'"
        } else {
            $orderAttributes += " replace='no'"
        }
        
        $command += "<add_order job_chain='$($JobChain)' $($orderAttributes)>"

        if ( $Parameters )
        {
            $command += '<params>'
            foreach ($p in $Parameters.GetEnumerator()) {
                $command += "<param name='$($p.Name)' value='$($p.Value)'/>"
            }            
            $command += '</params>'
        }
        
        $command += "</add_order>"

        $addOrder = Create-OrderObject
        $addOrder.Order = $Order
        $addOrder.JobChain = Get-JobSchedulerObject-Basename $JobChain
		$addOrder.Directory = Get-JobSchedulerObject-Parent $JobChain
        $addOrder.Title = $Title
        $addOrder.State = $State
        
        if ( !$NoImmediate )
        {
            Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to $($js.Url): $command"
            $addOrderXml = Send-JobSchedulerXMLCommand $js.Url $command
            $addOrder.Order = $addOrderXml.spooler.answer.ok.order.order
			$addOrder.Name = $addOrder.JobChain + ',' + $addOrder.Order			
			# for permanent orders
			# $addOrder.Path = $addOrder.Directory + '/' + $addOrder.Name		
			# for ad hoc orders
			$addOrder.Path = '/'
        }
        
        $addOrder
        $orderCount++
    }

    End
    {
        if ( $orderCount )
        {
            if ( !$NoImmediate )
            {
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($orderCount) orders added"                
            } else {
                $command = "<commands>$($command)</commands>"
                Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to $($js.Url): $command"
                $addOrderXml = Send-JobSchedulerXMLCommand $js.Url $command
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($orderCount) orders added"                
            }
        } else {
            Write-Warning "$($MyInvocation.MyCommand.Name): no order found to add"
        }

        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

Set-Alias -Name Add-Order -Value Add-JobSchedulerOrder
