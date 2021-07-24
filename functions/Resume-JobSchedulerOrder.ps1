function Resume-JobSchedulerOrder
{
<#
.SYNOPSIS
Resumes a number of orders in the JobScheduler Master.

.DESCRIPTION
This cmdlet is an alias for Update-JobSchedulerOrder -Action "resume"

.PARAMETER OrderId
Specifies the identifier of an order.

Both parameters -Order and -JobChain have to be specified if no pipelined order objects are used.

.PARAMETER JobChain
Specifies the path and name of a job chain for which orders should be stopped.

Both parameters -Order and -JobChain have to be specified if no pipelined order objects are used.

.PARAMETER Directory
Optionally specifies the folder where the job chain is located. The directory is determined
from the root folder, i.e. the "live" directory.

If the -JobChain parameter specifies the name of job chain then the location specified from the
-Directory parameter is added to the job chain location.

.PARAMETER Parameters
Specifies the parameters for the order. Parameters are created from a hashmap,
i.e. a list of names and values.

Example:
$orderParams = @{ 'param1' = 'value1'; 'param2' = 'value2' }

.PARAMETER State
Specifies that the order should resume the job chain at the job chain node that
is assigend the specified state.

.PARAMETER EndState
Specifies that the order should leave the job chain at the job chain node that
is assigend the specified state.

.PARAMETER AuditComment
Specifies a free text that indicates the reason for the current intervention, e.g. "business requirement", "maintenance window" etc.

The Audit Comment is visible from the Audit Log view of JOC Cockpit.
This parameter is not mandatory, however, JOC Cockpit can be configured to enforece Audit Log comments for any interventions.

.PARAMETER AuditTimeSpent
Specifies the duration in minutes that the current intervention required.

This information is visible with the Audit Log view. It can be useful when integrated
with a ticket system that logs the time spent on interventions with JobScheduler.

.PARAMETER AuditTicketLink
Specifies a URL to a ticket system that keeps track of any interventions performed for JobScheduler.

This information is visible with the Audit Log view of JOC Cockpit.
It can be useful when integrated with a ticket system that logs interventions with JobScheduler.

.INPUTS
This cmdlet accepts pipelined order objects that are e.g. returned from a Get-JobSchedulerOrder cmdlet.

.OUTPUTS
This cmdlet returns an array of order objects.

.EXAMPLE
Resume-JobSchedulerOrder -Order Reporting -JobChain /sos/reporting/Reporting

Resumes the order "Reporting" from the specified job chain.

.EXAMPLE
Get-JobSchedulerOrder | Resume-JobSchedulerOrder

Resumes all orders for all job chains.

.EXAMPLE
Get-JobSchedulerOrder -Directory / -Nosub-folders | Resume-JobSchedulerOrder

Resumes orders that are configured with the root folder ("live" directory)
without consideration of sub-folders.

.EXAMPLE
Get-JobSchedulerOrder -JobChain /test/globals/chain1 | Resume-JobSchedulerOrder

Resumes all orders for the specified job chain.

.LINK
about_jobscheduler

#>
[cmdletbinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OrderId,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $Parameters,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $State,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $EndState,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $AuditComment,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $AuditTimeSpent,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $AuditTicketLink
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-JobSchedulerStopWatch

        if ( !$AuditComment -and ( $AuditTimeSpent -or $AuditTicketLink ) )
        {
            throw "$($MyInvocation.MyCommand.Name): Audit Log comment required, use parameter -AuditComment if one of the parameters -AuditTimeSpent or -AuditTicketLink is used"
        }

        $objOrders = @()
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

        $objOrder = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'orderId' -value $OrderId -InputObject $objOrder
        Add-Member -Membertype NoteProperty -Name 'jobChain' -value $JobChain -InputObject $objOrder

        if ( $State )
        {
            Add-Member -Membertype NoteProperty -Name 'state' -value $State -InputObject $objOrder
        }

        if ( $EndState )
        {
            Add-Member -Membertype NoteProperty -Name 'endState' -value $EndState -InputObject $objOrder
        }

        if ( $Parameters )
        {
            $objParams = @()
            foreach( $parameter in $Parameters.GetEnumerator() )
            {
                $objParam = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'name' -value $parameter.key -InputObject $objParam
                Add-Member -Membertype NoteProperty -Name 'value' -value $parameter.value -InputObject $objParam
                $objParams += $objParam
            }

            Add-Member -Membertype NoteProperty -Name 'params' -value $objParams -InputObject $objOrder
        }


        $objOrders += $objOrder
    }

    End
    {
        if ( $objOrders.count )
        {
            $body = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

            if ( $AuditComment -or $AuditTimeSpent -or $AuditTicketLink )
            {
                $objAuditLog = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'comment' -value $AuditComment -InputObject $objAuditLog

                if ( $AuditTimeSpent )
                {
                    Add-Member -Membertype NoteProperty -Name 'timeSpent' -value $AuditTimeSpent -InputObject $objAuditLog
                }

                if ( $AuditTicketLink )
                {
                    Add-Member -Membertype NoteProperty -Name 'ticketLink' -value $AuditTicketLink -InputObject $objAuditLog
                }

                Add-Member -Membertype NoteProperty -Name 'auditLog' -value $objAuditLog -InputObject $body
            }

            Add-Member -Membertype NoteProperty -Name 'orders' -value $objOrders -InputObject $body

            if ( $PSCmdlet.ShouldProcess( '/orders/resume' ) )
            {
                [string] $requestBody = $body | ConvertTo-Json -Depth 100
                $response = Invoke-JobSchedulerWebRequest -Path '/orders/resume' -Body $requestBody

                if ( $response.StatusCode -eq 200 )
                {
                    $requestResult = ( $response.Content | ConvertFrom-Json )

                    if ( !$requestResult.ok )
                    {
                        throw ( $response | Format-List -Force | Out-String )
                    }
                } else {
                    throw ( $response | Format-List -Force | Out-String )
                }

                Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($objOrders.count) orders resumed"
            }
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no orders found"
        }

        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
