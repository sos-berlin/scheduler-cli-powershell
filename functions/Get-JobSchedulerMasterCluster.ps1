function Get-JobSchedulerMasterCluster
{
<#
.SYNOPSIS
Returns Master Cluster information from the JOC Cockpit.

.DESCRIPTION
Returns any JobScheduler Master Cluster members - including standalone instances - that are connected to JOC Cockpit.

.PARAMETER Id
Specifies the ID of a JobScheduler Master that was used during installation of the product.
If no ID is specified then the first JobScheduler Master registered with JOC Cockpit will be used.

.PARAMETER Active
This switch specifies that only the active instance of a JobScheduler Master cluster should be returned.

Without use of this switch active and passive Master instances in a cluster are returned.

.PARAMETER Passive
This switch specifies that only the passive instance of a JobScheduler Master cluster should be returned.

Without use of this switch active and passive Master instances in a cluster are returned.

.OUTPUTS
This cmdlet returns an array of Master Cluster member objects.

.EXAMPLE
$masters = Get-JobSchedulerMasterCluster

Returns all Master Clusters members.

.EXAMPLE
$masters = Get-JobSchedulerMasterCluster -Id some-jobscheduler-id

Returns the Master Cluster members with the specified JobScheduler ID ("some-jobscheduler-id").

.EXAMPLE
$activeMaster = Get-JobSchedulerMasterCluster -Id some-jobscheduler-id -Active

Returns the active Master Cluster member of a cluster with the specified JobScheduler ID ("some-jobscheduler-id").

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Id,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Active,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Passive
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch

        $returnMasterClusters = @()
    }
        
    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Id=$Id"

        if ( !$Id )
        {
            $Id = $script:jsWebService.JobSchedulerId
        }

        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $Id -InputObject $body
        
        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest -Path '/jobscheduler/cluster/members' -Body $requestBody
    
        if ( $response.StatusCode -eq 200 )
        {
            $returnMasterClusters = ( $response.Content | ConvertFrom-JSON ).masters
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }    

        if ( ( $Active -and $Passive ) -or ( !$Active -and !$Passive ) )
        {
            $returnMasterClusters        
        } elseif ( $Active ) {
            $returnMasterClusters | Where-Object { $_.jobschedulerId -eq $Id -and $_.state.severity -eq 0 }
        } elseif ( $Passive ) {
            $returnMasterClusters | Where-Object { $_.jobschedulerId -eq $Id -and $_.state.severity -eq 3 }
        }

        if ( $returnMasterClusters.count )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($returnMasterClusters.count) Master Clusters found"
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no Master Clusters found"
        }
    }

    End
    {
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
