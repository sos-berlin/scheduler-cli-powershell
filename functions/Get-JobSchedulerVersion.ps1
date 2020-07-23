function Get-JobSchedulerVersion
{
<#
.SYNOPSIS
Returns the JobScheduler Master version

.DESCRIPTION
The cmdlet returns the version of the JobScheduler Master.

.PARAMETER NoCache
Specifies that the cache for JobScheduler objects is ignored.
This results in the fact that for each Get-JobScheduler* cmdlet execution the response is 
retrieved directly from the JobScheduler Master and is not resolved from the cache.

.EXAMPLE
Get-JobSchedulerVersion

Returns the JobScheduler version.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
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

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest '/jobscheduler/p' $requestBody
    
        if ( $response.StatusCode -eq 200 )
        {
            $returnStatus = ( $response.Content | ConvertFrom-JSON ).jobscheduler
            $returnStatus.version            
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }    
    }

    End
    {
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }    
}
