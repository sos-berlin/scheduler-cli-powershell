function Use-JobSchedulerWebService
{
<#
.SYNOPSIS
Connects to the JobScheduler Web Service.

.DESCRIPTION
This cmdlet can be used with the JobScheduler Web Service starting from release 1.11.

A connection to the JobScheduler Web Service is established including support for credentials 
and use of a proxy.

The cmdlet authenticates a user and returns an access token in case of successful authentication
that can be used for subsequent requests to the Web Service.

.PARAMETER Url
Specifies the URL to access the Web Service.

.PARAMETER Id
Specifies the ID of a JobScheduler Master.

.PARAMETER Credentials
Specifies a credentials object that is used to authenticate the account with the JobScheduler Web Service.

Credentials sets can be managed with Windows built-in tools such as:

* PS C:\> cmdkey /generic:JobScheduler Web Service /user:root /pass:secret
* The Windows Credential Manager that is available Windows Control Panel.

A previously created credentials set can be retrieved by use of the cmdlet:

* PS C:\> $credentials = Get-JobSchedulerSystemCredentials -TargetName "JobScheduler Web Service"

The credentials object can be assigned to the -Credentials parameter.

.EXAMPLE
cmdkey /generic:JobScheduler Web Service /user:root /pass:secret
$credentials = Get-JobSchedulerSystemCredentials -TargetName "JobScheduler Web Service"
Use-JobSchedulerWebService http://localhost:4446 -Credentials $credentials

Prior to use with PowerShell with some external command ("cmdkey") a credentials set is generated for the current user.
The credentials are retrieved by use of the Get-JobSchedulerSystemCredentials cmdlet and are forwarded to the Use-JobSchedulerWebService cmdlet.

The cmdlet returns an object with access information including the access token for the JobScheduler Web Service.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $Url,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Id,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Management.Automation.PSCredential] $Credentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [Uri] $ProxyUrl,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Management.Automation.PSCredential] $ProxyCredentials
)
    Begin
    {
        $stopWatch = Start-StopWatch
    }

    Process
    {
        if ( $Url )
        {
            # is protocol provided? e.g. http://localhost:4446
            if ( !$Url.OriginalString.startsWith('http://') -and !$Url.OriginalString.startsWith('https://') )
            {
                $Url = 'http://' + $Url.OriginalString
            }

            # is valid hostname specified?
            if ( [System.Uri]::CheckHostName( $Url.DnsSafeHost ).equals( [System.UriHostNameType]::Unknown ) )
            {
                throw "$($MyInvocation.MyCommand.Name): no valid hostname specified, check use of -Url parameter, e.g. -Url http://localhost:4444: $($Url.OriginalString)"
            }

            if ( !$jsWebService )
            {
                $SCRIPT:jsWebService = Create-WebServiceObject
            }

            $SCRIPT:jsWebService.Url = $Url
        }

        if ( $ProxUrl )
        {
            # is protocol provided? e.g. http://localhost:3128
            if ( !$ProxyUrl.OriginalString.startsWith('http://') -and !$ProxyUrl.OriginalString.startsWith('https://') )
            {
                $ProxyUrl = 'http://' + $ProxyUrl.OriginalString
            }

            # is valid hostname specified?
            if ( [System.Uri]::CheckHostName( $ProxyUrl.DnsSafeHost ).equals( [System.UriHostNameType]::Unknown ) )
            {
                throw "$($MyInvocation.MyCommand.Name): no valid hostname specified, check use of -ProxyUrl parameter, e.g. -ProxyUrl http://localhost:3128: $($Url.OriginalString)"
            }            
        }

        if ( $Id )
        {
            if ( !$SCRIPT:jsWebService )
            {
                $SCRIPT:jsWebService = Create-WebServiceObject
            }

            $SCRIPT:jsWebService.Id = $Id
        }

        if ( $Credentials )
        {
            $SCRIPT:jsWebServiceOptionWebRequestUseDefaultCredentials = $false
            $SCRIPT:jsWebServiceCredentials = $Credentials
        } elseif ( $SCRIPT:jsWebService ) {
            $Credentials = $SCRIPT:jsWebServiceCredentials
        }
        
        if ( $ProxyCredentials )
        {
            $SCRIPT:jsWebServiceOptionWebRequestProxyUseDefaultCredentials = $false
            $SCRIPT:jsWebServiceProxyCredentials = $ProxyCredentials
        } elseif ( $SCRIPT:jsWebServiceProxyCredentials ) {
            $ProxyCredentials = $SCRIPT:jsWebServiceProxyCredentials
        }

        try
        {
            $authenticationUrl = $Url.scheme + '://' + $Url.Authority + '/joc/api/security/login'
            $headers = @{}
            
            if ( $Credentials )
            {
                $basicAuthentication = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes( $Credentials.GetNetworkCredential().UserName + ':' + $Credentials.GetNetworkCredential().Password ))
                $headers = @{ 'Authorization'="Basic $($basicAuthentication)" }
            }
            
            Write-Debug ".. $($MyInvocation.MyCommand.Name): sending authentication request to JobScheduler Web Service $($authenticationUrl)"
            $response = Send-JobSchedulerWebServiceRequest -Url $authenticationUrl -Method 'POST' -ContentType 'application/json' -Headers $headers
            
            if ( $response )
            {
                if ( $ProxyUrl )
                {
                    $SCRIPT:jsWebService.ProxyUrl = $ProxyUrl
                }
            
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): access token: $($response.accessToken)"
                $SCRIPT:jsWebService
            }
        } catch {
            throw "$($MyInvocation.MyCommand.Name): Authentication error occurred: $($_.Exception.Message)"
        }
    }

    End
    {
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
