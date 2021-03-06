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
Remove-JobSchedulerService

Removes the Windows service.

.EXAMPLE
Remove-JobSchedulerService -Backup

Removes the Windows service for a JobScheduler backup instance in a passive cluster.

.LINK
about_jobscheduler

#>
[cmdletbinding(SupportsShouldProcess)]
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

        $serviceName = $script:js.Service.ServiceName
        $serviceDisplayName = $script:js.Service.ServiceDisplayName

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
                    if ( $PSCmdlet.ShouldProcess( 'Master', 'Stop-Service' ) )
                    {
                        Stop-Service -Name $serviceName | Out-Null
                    }

                    Start-Sleep -s 3
                }

                Write-Verbose ".. $($MyInvocation.MyCommand.Name): remove existing JobScheduler service: $($serviceName)"
                if ( $PSCmdlet.ShouldProcess( 'Master', 'Remove-CimInstance' ) )
                {
                    # $wmiService = Get-WmiObject -Class Win32_Service -Filter "Name='$($serviceName)'"
                    # $wmiService.Delete()
                    $cimService = Get-CimInstance win32_service -Filter "name='$($serviceName)'"
                    Remove-CimInstance -InputObject $cimService
                }

                Start-Sleep -s 5
            }
        } catch {
            throw "$($MyInvocation.MyCommand.Name): could not remove existing service: $($_.Exception.Message)"
        }

        Write-Verbose ".. $($MyInvocation.MyCommand.Name): JobScheduler service removed: $($serviceName)"
    }
}
