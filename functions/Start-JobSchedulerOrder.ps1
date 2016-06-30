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
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
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
            if ( (Get-JobSchedulerObject-Basename $Order) -ne $Order ) # order id includes a directory
            {
                $Directory = Get-JobSchedulerObject-Parent $Order
                $Order = Get-JobSchedulerObject-Basename $Order
                if ( $Directory -eq '/' )
                {
                    $JobChain = $Directory + (Get-JobSchedulerObject-Basename $JobChain)
                } else {
                    $JobChain = $Directory + '/' + (Get-JobSchedulerObject-Basename $JobChain)
                }
            }
        }
    
        $o = Create-OrderObject
        $o.Order = $Order
        $o.JobChain = $JobChain
        $o.Directory = $Directory
        $o.Parameters = $Parameters
        $o.Title = $Title
        if ( $At )
        {
            $o.At = $At
        } else {
            $o.At = 'now'
        }
        $o.State = $State
        $o.EndState = $EndState
        $startOrders += $o
    }

    End
    {
        $startOrders | Update-JobSchedulerOrder -Action start
    }
}

Set-Alias -Name Start-Order -Value Start-JobSchedulerOrder
