function Remove-JobSchedulerService
{
<#
.SYNOPSIS
Removes an existing JobScheduler Windows service. This operation requires elevated privileges of a Windows administrator.

.DESCRIPTION
JobScheduler is commonly operated as a Windows service.
The cmdlet removes the service.

.PARAMETER Backup
Specifies that the current JobScheduler instance is a backup instance in a passive cluster.

Backup instances use the same JobScheduler ID and database connection as the primary instance.

.EXAMPLE
Remove-Service

Removes the Windows service.

.EXAMPLE
Remove-Service -Backup

Removes the Windows service for a JobScheduler backup instance in a passive cluster.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Backup
)
	Begin
	{
		Approve-JobSchedulerCommand $MyInvocation.MyCommand
	}

    Process
    {
        $service = $null
        
        $serviceName = $js.Service.ServiceName
        $serviceDisplayName = $js.Service.ServiceDisplayName

        if ( $Backup )
        {
            $serviceName += '_backup'
            $serviceDisplayName += ' -backup'
        }
        
        # Check an existing service
        try 
        {
            $service = Get-Service $serviceName -ErrorAction SilentlyContinue
        } catch {
            throw "$($MyInvocation.MyCommand.Name): could not find existing service: $($_.Exception.Message)"
        }
        
        # Remove an existing service
        try
        {
            if ( $service )
            {
                if ( $service -and $service.Status -eq "running" )
                {
                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): stop existing JobScheduler service: $($serviceName)"       
                    $result = Stop-Service -Name $serviceName
                    Start-Sleep -s 3
                }

                Write-Verbose ".. $($MyInvocation.MyCommand.Name): remove existing JobScheduler service: $($serviceName)"       
                $wmiService = Get-WmiObject -Class Win32_Service -Filter "Name='$($serviceName)'"
                $wmiService.Delete()
                Start-Sleep -s 5
            }
        } catch {
            throw "$($MyInvocation.MyCommand.Name): could not remove existing service: $($_.Exception.Message)"
        }
                
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): JobScheduler service removed: $($serviceName)"
    }
}

Set-Alias -Name Remove-Service -Value Remove-JobSchedulerService
