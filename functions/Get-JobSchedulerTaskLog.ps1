function Get-JobSchedulerTaskLog
{
<#
.SYNOPSIS
Read the task log from the JobScheduler History.

.DESCRIPTION
Reads a task log for a given task ID. This cmdlet is mostly used for pipelined input from the
Get-JobSchedulerTaskHistory cmdlet that allows to search the execution history of tasks and
that returns task IDs that are used by this cmdlet to retrieve the task's log output.

.PARAMETER TaskId
Specifies the ID that the task was running with. This information is provided by the
Get-JobSchedulerTaskHistory cmdlet.

.PARAMETER Job
This parameter is used to accept pipeline input from the Get-JobSchedulerTaskHistory cmdlet and forwards the parameter to the resulting object.

.PARAMETER StartTime
This parameter is used to accept pipeline input from the Get-JobSchedulerTaskHistory cmdlet and forwards the parameter to the resulting object.

.PARAMETER EndTime
This parameter is used to accept pipeline input from the Get-JobSchedulerTaskHistory cmdlet and forwards the parameter to the resulting object.

.PARAMETER ExitCode
This parameter is used to accept pipeline input from the Get-JobSchedulerTaskHistory cmdlet and forwards the parameter to the resulting object.

.PARAMETER State
This parameter is used to accept pipeline input from the Get-JobSchedulerTaskHistory cmdlet and forwards the parameter to the resulting object.

.PARAMETER Criticality
This parameter is used to accept pipeline input from the Get-JobSchedulerTaskHistory cmdlet and forwards the parameter to the resulting object.

.PARAMETER JobSchedulerId
This parameter is used to accept pipeline input from the Get-JobSchedulerTaskHistory cmdlet and forwards the parameter to the resulting object.

.PARAMETER ClusterMember
This parameter is used to accept pipeline input from the Get-JobSchedulerTaskHistory cmdlet and forwards the parameter to the resulting object.

.INPUTS
This cmdlet accepts pipelined task history objects that are e.g. returned from the Get-JobSchedulerTaskHistory cmdlet.

.OUTPUTS
This cmdlet returns and an object with history properties including the task log.

.EXAMPLE
Get-JobSchedulerTaskHistory -Job /some/job174 | Get-JobSchedulerTaskLog

Retrieves the most recent task log for the given job.

.EXAMPLE
Get-JobSchedulerTaskHistory -Job /some/job174 | Get-JobSchedulerTaskLog | Out-File /tmp/job174.log -Encoding Unicode

Writes the task log to a file.

.EXAMPLE
Get-JobSchedulerTaskHistory -RelativeDateFrom -8h | Get-JobSchedulerTaskLog | Select-Object @{name='path'; expression={ "/tmp/history/$(Get-Date $_.startTime -f 'yyyyMMdd-hhmmss')-$([io.path]::GetFileNameWithoutExtension($_.job)).log"}}, @{name='value'; expression={ $_.log }} | Set-Content

Read the logs of tasks that completed within the last 8 hours and writes the log output to individual files. The log file names are created from the start time and the job name of each task.

.EXAMPLE
# execute once
$lastHistory = Get-JobSchedulerTaskHistory -RelativeDateFrom -8h | Sort-Object -Property startTime
# execute by interval
Get-JobSchedulerTaskHistory -DateFrom $lastHistory[0].startTime | Tee-Object -Variable lastHistory | Get-JobSchedulerTaskLog | Select-Object @{name='path'; expression={ "/tmp/history/$(Get-Date $_.startTime -f 'yyyyMMdd-hhmmss')-$([io.path]::GetFileNameWithoutExtension($_.job)).log"}}, @{name='value'; expression={ $_.log }} | Set-Content

Provides a mechanism to subsequently retrieve previous logs. Starting from intial execution of the Get-JobSchedulerTaskHistory cmdlet the resulting $lastHistory object is used for any subsequent calls. 
Consider use of the Tee-Object cmdlet in the pipeline that updates the $lastHistory object that can be used for later executions of the same pipeline. 
The pipeline can e.g. be executed in a cyclic job.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $TaskId,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Job,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [datetime] $StartTime,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [datetime] $EndTime,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [int] $ExitCode,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [PSCustomObject] $State,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Criticality,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobSchedulerId,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $ClusterMember
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
        Add-Member -Membertype NoteProperty -Name 'taskId' -value $TaskId -InputObject $body

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest -Path '/task/log/info' -Body $requestBody
            
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
        $response = Invoke-JobSchedulerWebRequest -Path '/task/log/download' -Body $requestBody
            
        if ( $response.StatusCode -ne 200 )
        {
            throw ( $response | Format-List -Force | Out-String )
        }
        
        $objResult = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'clusterMember' -value $ClusterMember -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'criticality' -value $Criticality -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'endTime' -value $EndTime -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'exitCode' -value $ExitCode -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'job' -value $Job -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $JobSchedulerId -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'startTime' -value $StartTime -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'state' -value $State -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'taskId' -value $State -InputObject $objResult
        Add-Member -Membertype NoteProperty -Name 'log' -value ([System.Text.Encoding]::UTF8.GetString( $response.Content )) -InputObject $objResult
        
        $objResult
    }

    End
    {
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
