function Get-JobSchedulerOrderLog
{
<#
.SYNOPSIS
Read the order log from the JobScheduler History.

.DESCRIPTION
Reads an order log for a given job chain, order ID and history ID. This cmdlet is mostly used for pipelined input from the
Get-JobScchedulerOrderHistory cmdlet that allows to search the execution history of orders and
that returns history IDs that are used by this cmdlet to retrieve the orders's log output.

.PARAMETER HistoryId
Specifies the history ID that the orders was running for. This information is provided by the
Get-JobSchedulerOrderHistory cmdlet.

.PARAMETER OrderId
This parameter specifies the order that was running for the given history ID.

.PARAMETER JobChain
This parameter specifies the job chain path that the order is assigned.

.PARAMETER Path
This parameter is used to accept pipeline input from the Get-JobSchedulerOrderHistory cmdlet and forwards the parameter to the resulting object.

.PARAMETER Node
This parameter is used to accept pipeline input from the Get-JobSchedulerOrderHistory cmdlet and forwards the parameter to the resulting object.

.PARAMETER StartTime
This parameter is used to accept pipeline input from the Get-JobSchedulerOrderHistory cmdlet and forwards the parameter to the resulting object.

.PARAMETER EndTime
This parameter is used to accept pipeline input from the Get-JobSchedulerOrderHistory cmdlet and forwards the parameter to the resulting object.

.PARAMETER ExitCode
This parameter is used to accept pipeline input from the Get-JobSchedulerOrderHistory cmdlet and forwards the parameter to the resulting object.

.PARAMETER State
This parameter is used to accept pipeline input from the Get-JobSchedulerOrderHistory cmdlet and forwards the parameter to the resulting object.

.PARAMETER JobSchedulerId
This parameter is used to accept pipeline input from the Get-JobSchedulerOrderHistory cmdlet and forwards the parameter to the resulting object.

.INPUTS
This cmdlet accepts pipelined order history objects that are e.g. returned from the Get-JobSchedulerOrderHistory cmdlet.

.OUTPUTS
This cmdlet returns and an object with history properties including the order log.

.EXAMPLE
Get-JobSchedulerOrderHistory -JobChain /product_demo/shell_chain | Get-JobSchedulerOrderLog

Retrieves the most recent order log for the given job chain.

.EXAMPLE
Get-JobSchedulerOrderHistory -JobChain /product_demo/shell_chain | Get-JobSchedulerOrderLog | Out-File /tmp/shell_chain.log -Encoding Unicode

Writes the order log to a file.

.EXAMPLE
Get-JobSchedulerOrderHistory -RelativeDateFrom -8h | Get-JobSchedulerOrderLog | Select-Object @{name='path'; expression={ "/tmp/history/$(Get-Date $_.startTime -f 'yyyyMMdd-hhmmss')-$([io.path]::GetFileNameWithoutExtension($_.jobChain))-$($_.orderId).log"}}, @{name='value'; expression={ $_.log }} | Set-Content

Read the logs of orders that completed within the last 8 hours and writes the log output to individual files. The log file names are created from the start time, the job chain name and order ID.

.EXAMPLE
# execute once
$lastHistory = Get-JobSchedulerOrderHistory -RelativeDateFrom -8h | Sort-Object -Property startTime
# execute by interval
Get-JobSchedulerOrderHistory -DateFrom $lastHistory[0].startTime | Tee-Object -Variable lastHistory | Get-JobSchedulerOrderLog | Select-Object @{name='path'; expression={ "/tmp/history/$(Get-Date $_.startTime -f 'yyyyMMdd-hhmmss')-$([io.path]::GetFileNameWithoutExtension($_.jobChain))-$($_.orderId).log"}}, @{name='value'; expression={ $_.log }} | Set-Content

Provides a mechanism to subsequently retrieve previous logs. Starting from intial execution of the Get-JobSchedulerOrderHistory cmdlet the resulting $lastHistory object is used for any subsequent calls. 
Consider use of the Tee-Object cmdlet in the pipeline that updates the $lastHistory object that can be used for laster executions of the same pipeline. 
The pipeline can e.g. be executed in a cyclic job.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $HistoryId,
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $OrderId,
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Path,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Node,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [datetime] $StartTime,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [datetime] $EndTime,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [int] $ExitCode,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [PSCustomObject] $State,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobSchedulerId
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch
    }
    
    Process
    {
        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
        Add-Member -Membertype NoteProperty -Name 'historyId' -value $HistoryId -InputObject $body
        Add-Member -Membertype NoteProperty -Name 'orderId' -value $OrderId -InputObject $body
        Add-Member -Membertype NoteProperty -Name 'jobChain' -value $JobChain -InputObject $body

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest -Path '/order/log/info' -Body $requestBody
            
        if ( $response.StatusCode -eq 200 )
        {
            $requestResult = ( $response.Content | ConvertFrom-JSON )
                
            if ( !$requestResult.log )
            {
                throw ( $response | Format-List -Force | Out-String )
            }
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }
        
        
        Write-Verbose ".. log file: size=$($requestResult.log.size), filename=$($requestResult.log.filename), download=$($requestResult.log.download)"
        Add-Member -Membertype NoteProperty -Name 'filename' -value $requestResult.log.filename -InputObject $body
        
        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest -Path '/order/log/download' -Body $requestBody
            
            
        if ( $response.StatusCode -ne 200 )
        {
            throw ( $response | Format-List -Force | Out-String )
        }
        
        # [System.Text.Encoding]::UTF8.GetString( $response.Content )
        $objResult = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'endTime' -value $EndTime -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'exitCode' -value $ExitCode -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'historyId' -value $HistoryId -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'jobChain' -value $JobChain -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $JobSchedulerId -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'node' -value $Node -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'path' -value $Path -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'startTime' -value $StartTime -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'state' -value $State -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'orderId' -value $OrderId -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'log' -value ([System.Text.Encoding]::UTF8.GetString( $response.Content )) -InputObject $objResult
        
        $objResult
    }

    End
    {
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
