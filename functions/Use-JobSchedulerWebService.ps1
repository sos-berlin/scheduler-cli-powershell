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

.PARAMETER Base
The Base is used as a prefix to the Path for web service URLs and is configured with the web server
that hosts the JobScheduler Web Service.

This value is fixed and should not be modified for most use cases.

Default: /joc/api

.PARAMETER Disconnect
This parameter is used to disconnect from a previously connected JobScheduler Web Service.

After successful connection to the JobScheduler Web Service a session is established that
will last until this cmdlet is used with the Disconnect parameter or the session timeout has been exceeded.

It is recommended to disconnect from the JobScheduler Web Service in order to ensure that the
current session is closed.

This parameter cannot be used with other parameters.

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
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Id,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Management.Automation.PSCredential] $Credentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [switch] $UseDefaultCredentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [Uri] $ProxyUrl,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Management.Automation.PSCredential] $ProxyCredentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [switch] $ProxyUseDefaultCredentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Base = '/joc/api',
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [int] $Timeout = 30,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $SSLProtocol,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Certificate,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $AddRootCertificate,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [switch] $SkipCertificateCheck,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Disconnect
)
    Begin
    {
        $stopWatch = Start-StopWatch
    }

    Process
    {
        if ( !$jsWebService )
        {
            $script:jsWebService = Create-WebServiceObject
        }

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
                throw "$($MyInvocation.MyCommand.Name): no valid hostname specified, check use of -Url parameter, e.g. -Url http://localhost:4446: $($Url.OriginalString)"
            }

            $script:jsWebService.Url = $Url
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

            $script:jsWebService.ProxyUrl = $ProxyUrl
        }

        if ( $Base )
        {
            $script:jsWebService.Base = $Base
        }

        if ( $Id )
        {
            $script:jsWebService.JobSchedulerId = $Id
        }

        if ( $Credentials )
        {
            $script:jsWebServiceOptionWebRequestUseDefaultCredentials = $false
            $script:jsWebServiceCredential = $Credentials
        } elseif ( $script:jsWebService ) {
            $Credentials = $script:jsWebServiceCredential
        }
        
        if ( $ProxyCredentials )
        {
            $script:jsWebServiceOptionWebRequestProxyUseDefaultCredentials = $false
            $script:jsWebServiceProxyCredential = $ProxyCredentials
        } elseif ( $script:jsWebServiceProxyCredential ) {
            $ProxyCredentials = $script:jsWebServiceProxyCredential
        }

        if ( $Disconnect )
        {
            $path = '/security/logout'
        } else {
            $path = '/security/login'
        }
        
        if ( $Url.UserInfo )
        {
            $authenticationUrl = $Url.scheme + '://' + $Url.UserInfo + '@' + $Url.Authority + $Base + $path
        } else {
            $authenticationUrl = $Url.scheme + '://' + $Url.Authority + $Base + $path
        }

        if ( $AddRootCertificate )
        {
            # add root certificate to truststore
            #     see https://github.com/PowerShell/PowerShell/issues/1865
            #     see https://github.com/dotnet/corefx/blob/master/Documentation/architecture/cross-platform-cryptography.md
            $storeName = [System.Security.Cryptography.X509Certificates.StoreName]
            $storeLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]
            $openFlags = [System.Security.Cryptography.X509Certificates.OpenFlags]
            $store = [System.Security.Cryptography.X509Certificates.X509Store]::new( $storeName::Root, $storeLocation::CurrentUser )
            
            $X509Certificate2 = [System.Security.Cryptography.X509Certificates.X509Certificate2]
            $certPath = ( Resolve-Path $RootCertificate ).Path
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2( $certPath )
            
            $store.Open( $openFlags::ReadWrite )
            $store.Add( $cert )
            $store.Close()        
        }

        $requestParams = @{}
        $requestParams.Add( 'Uri', $authenticationUrl )
        
        if ( $Disconnect -and $script:jsWebService )
        {
            $requestParams.Add( 'Headers', @{ 'Accept' = 'application/json'; 'Content-Type' = 'application/json'; 'X-Access-Token' = $script:jsWebService.AccessToken } )
        } else {
            $requestParams.Add( 'Headers', @{ 'Accept' = 'application/json'; 'Content-Type' = 'application/json' } )
        }
        $requestParams.Add( 'ContentType', 'application/json' )
        $requestParams.Add( 'Method', 'POST' )

        if ( isPowerShellVersion 6 )
        {
            $requestParams.Add( 'AllowUnencryptedAuthentication', $true )
            $requestParams.Add( 'SkipHttpErrorCheck', $true )
        }

        if ( $UseDefaultCredentials )
        {
            # Windows only
            $requestParams.Add( 'UseDefaultCredentials', $true )
        } elseif ( $Credentials ) {
            if ( isPowerShellVersion 6 )
            {
                $requestParams.Add( 'Authentication', 'Basic' )
            } else {
                $basicAuthentication = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes( $Credentials.GetNetworkCredential().UserName + ':' + $Credentials.GetNetworkCredential().Password ))
                $requestParams['Headers'].Add( 'Authorization', "Basic $($basicAuthentication)" )
            }

            $requestParams.Add( 'Credential', $Credentials )
        } else {
            throw "no credentials specified, use -Credential parameter"
        }

        if ( $ProxyUrl )
        {
            $requestParams.Add( 'Proxy', $ProxyUrl )
            $script:jsWebService.ProxyUrl = $ProxyUrl
        }

        if ( $ProxyUseDefaultCredentials )
        {
            # Windows only
            $requestParams.Add( 'ProxyUseDefaultCredentials', $true )
        } elseif ( $ProxyCredentials ) {
            $requestParams.Add( 'ProxyCredential', $ProxyCredentials )
        }

        if ( $Timeout )
        {
            $requestParams.Add( 'TimeoutSec', $Timeout )
            $script:jsWebService.Timeout = $Timeout
        }

        if ( $SkipCertificateCheck )
        {
            $requestParams.Add( 'SkipCertificateCheck', $true )
            $script:jsWebService.SkipCertificateCheck = $true
        }
        
        if ( $SSLProtocol )
        {
            # $requestParams.Add( 'SSLProtocol', 'Tls' )
            # $requestParams.Add( 'SSLProtocol', 'Tls12' )
            # $requestParams.Add( 'SSLProtocol', 'Tls,Tls11,Tls12' )
            $requestParams.Add( 'SSLProtocol', $SSLProtocol )
            $script:jsWebService.SSLProtcol = $SSLProtocol
        }

        if ( $Certificate )
        {
            # Client Certificate
            $clientCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2( $Certificate )
            $requestParams.Add( 'Certificate', $clientCert )
            $script:jsWebService.Certificate = $clientCert
        }

        try {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): sending request to JobScheduler Web Service $($authenticationUrl)"
            Write-Debug ".... Invoke-WebRequest:"
        
            $requestParams.Keys | % {
                if ( $_ -eq 'Headers' )
                {
                    $item = $_
                    $requestParams.Item($_).Keys | % {
                        Write-Debug "...... Headers $_ : $($requestParams.Item($item).Item($_))"
                    }
                } else {
                    Write-Debug "...... $_  $($requestParams.Item($_))"
                }
            }

            $response = Invoke-WebRequest @requestParams

            if ( $response -and $response.StatusCode -eq 200 -and $response.Content )
            {
                if ( $Disconnect )
                {
                    $script:js = Create-JSObject
                    $script:jsWebService = Create-WebServiceObject
                    $script:jsWebServiceCredential = $null
                } else {
                    $content = $response.Content | ConvertFrom-JSON
                    $script:jsWebService.AccessToken = $content.AccessToken

                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): access token: $($response.accessToken)"
                    $script:jsWebService
                }
            } else {
                $message = $response | Format-List -Force | Out-String
                throw $message
            }        
        } catch {
            $message = $_.Exception | Format-List -Force | Out-String
            throw $message
        }        
    }

    End
    {
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
