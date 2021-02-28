function Disconnect-JobScheduler
{
<#
.SYNOPSIS
Disconnects from the JobScheduler JOC Cockpit Web Service.

.DESCRIPTION
This cmdlet can be used to disconnect from the JobScheduler JOC Cockpit Web Service.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
)
    Process
    {
        $response = Invoke-JobSchedulerWebRequest -Path '/security/logout' -Body ""

        if ( $response.StatusCode -eq 200 )
        {
            $requestResult = ( $response.Content | ConvertFrom-JSON )

            if ( $requestResult.isAuthenticated -ne $false )
            {
                throw ( $response | Format-List -Force | Out-String )
            }
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }

        $script:js = New-JobSchedulerObject
        $script:jsWebService = Create-WebServiceObject
        $script:jsWebServiceCredential = $null
    }
}
