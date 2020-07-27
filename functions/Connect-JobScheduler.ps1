function Connect-JobScheduler
{
<#
.SYNOPSIS
Connects to the JobScheduler JOC Cockpit Web Service.

.DESCRIPTION
This cmdlet can be used with the JobScheduler JOC Cockpit Web Service starting from release 1.11.

A connection to the Web Service is established including support for credentials 
and use of a proxy.

The cmdlet authenticates a user and returns an access token in case of successful authentication
that can be used for subsequent requests to the Web Service.

.PARAMETER Url
Specifies the URL to access the Web Service.

.PARAMETER Credentials
Specifies a credentials object that is used to authenticate the account with the JobScheduler Web Service.

Credentials can be specified in a script:

* PS C:\> $credential = ( New-Object -typename System.Management.Automation.PSCredential -ArgumentList 'root', ( 'root' | ConvertTo-SecureString -AsPlainText -Force) )

Credentials sets can be managed with Windows built-in tools such as:

* PS C:\> cmdkey /generic:JobScheduler Web Service /user:root /pass:secret
* The Windows Credential Manager that is available Windows Control Panel.

A previously created credentials set can be retrieved by use of the cmdlet:

* PS C:\> $credentials = Get-JobSchedulerSystemCredentials -TargetName "JobScheduler Web Service"

The credentials object can be assigned the -Credentials parameter.

.PARAMETER UseDefaultCredentials
This parameter currently is not used. It is provided for future versions of JOC Cockpit that support single sign on.

.PARAMETER ProxyUrl
If JOC Cockpit is accessed via a proxy server then the proxy server URL is specified with this parameter.

.PARAMETER ProxyCredentials
If JOC Cockpit is accessed via a proxy server that requires authentication then the credential set
for the proxy server can be specified with this parameter.

.PARAMETER ProxyUseDefaultCredentials
This parameter currently is not used. It is provided for future versions of JOC Cockpit that support single sign on.

.PARAMETER Id
Specifies the ID of a JobScheduler Master that was used during installation of the product.
If no ID is specified then the first JobScheduler Master registered with JOC Cockpit will be used.

.PARAMETER AskForCredentials
Specifies that the user is prompted for the account and password that are used for authentication with JobScheduler.

.PARAMETER Base
The Base is used as a prefix to the Path for web service URLs and is configured with the web server
that hosts the JobScheduler Web Service.

This value is fixed and should not be modified for most use cases.

Default: /joc/api

.PARAMETER Timeout
Specifies the timeout to wait for the JOC Cockpit Web Service response.

.PARAMETER SSLProtocol
This parameter can be used to specify the TLS protocol version that should be used. The protocol version is agreed
on between the JOC Cockpit web server and the PowerShell client. Both server and client have to identify a common
protocol version.

* -SSLProtocol 'Tls'
** use any TLS protocol version available
* -SSLProtocol 'Tls12'
** use TLS protocol version 1.2 only
* -SSLProtocol 'Tls11,Tls12'
** use TLS protocol version 1.1 or 1.2 only

.PARAMETER Certificate
This parameter currently is not used. It is provided for future releases of JOC Cockpit
that support client authentication certificates.

The certificate specified with this parameter replaces the account/password specified during login.

.PARAMETER AddRootCertificate
Specifies the location of a file that holds the root certificate that was when signing the JOC Cockpit
SSL certificate. 

* For Windows environments the root certificate by default is looked up in the Windows Certificate Store, however, 
  this parameter can be used to apply a root certificate from a location in the file system.
* For Linux environments a path is specified to the root certificate file.

.PARAMETER SkipCertificateCheck
Specifies that the JOC Cockpit SSL certificate will not be checked, i.e. the identify of the JOC Cockpit instance is not verified.

Use of this parameter is strongly discouraged with secure environments as it trusts a JOC Cockpit SSL certificate without verification.

.EXAMPLE
Connect-JobScheduler http://localhost4446 -AskForCredentials

Connects to the JobScheduler Web Service at the indicated address and asks the user interactively to enter credentials.
.EXAMPLE
$credential = ( New-Object -typename System.Management.Automation.PSCredential -ArgumentList 'root', ( 'root' | ConvertTo-SecureString -AsPlainText -Force) )
Connect-JobScheduler http://localhost:4446 $credential scheduler

A variable $credential is created that holds the credentials for the default root account of JOC Cockpit.
When calling the cmdlet the URL is specified, the JobSchedulerID that was used during installationn and the credential object.

.EXAMPLE
cmdkey /generic:JobScheduler Web Service /user:root /pass:root
$credentials = Get-JobSchedulerSystemCredentials -TargetName "JobScheduler Web Service"
Connect-JobScheduler -Url http://localhost:4446 -Credentials $credentials

Prior to use with PowerShell with some external command ("cmdkey") a credential set is generated for the current user.
The credentials are retrieved by use of the Get-JobSchedulerSystemCredentials cmdlet and are forwarded to the Connect-JobScheduler cmdlet.

.OUTPUTS
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
    [System.Management.Automation.PSCredential] $Credentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Id,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $AskForCredentials,
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
    [switch] $SkipCertificateCheck
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

        if ( $ProxyUrl )
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

        if ( $Id )
        {
            $script:jsWebService.JobSchedulerId = $Id
        }
        
        if ( $Base )
        {
            $script:jsWebService.Base = $Base
        }

        if ( $AskForCredentials )
        {
            Write-Host '* ***************************************************** *'
            Write-Host '* JobScheduler Web Service credentials                  *'
            Write-Host '* enter account and password for authentication         *'
            Write-Host '* ***************************************************** *'
            $account = Read-Host 'Enter account for JobScheduler Web Service '
            
            if ( $account )
            {
                $password = Read-Host 'Enter password for JobScheduler Web Service: ' -AsSecureString
                $Credentials = ( New-Object -typename System.Management.Automation.PSCredential -ArgumentList $account, $password )
            }
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

        if ( $Url.UserInfo )
        {
            $authenticationUrl = $Url.scheme + '://' + $Url.UserInfo + '@' + $Url.Authority + $Base + '/security/login'
        } else {
            $authenticationUrl = $Url.scheme + '://' + $Url.Authority + $Base + '/security/login'
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
        $requestParams.Add( 'Verbose', $false )
        $requestParams.Add( 'Uri', $authenticationUrl )
        $requestParams.Add( 'Headers', @{ 'Accept' = 'application/json'; 'Content-Type' = 'application/json' } )
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
            throw "no credentials specified, use -Credentials parameter"
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
            # Client Authentication Certificate
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
                $content = $response.Content | ConvertFrom-JSON
                $script:jsWebService.AccessToken = $content.AccessToken
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): access token: $($content.accessToken)"
            } else {
                $message = $response | Format-List -Force | Out-String
                throw $message
            }        

            if ( !$script:jsWebService.JobSchedulerId )
            {
                $body = New-Object PSObject
       
                [string] $requestBody = $body | ConvertTo-Json -Depth 100
                $response = Invoke-JobSchedulerWebRequest -Path '/jobscheduler/ids' -Body $requestBody
           
                if ( $response.StatusCode -eq 200 )
                {
                    $script:jsWebService.JobSchedulerId = ( $response.Content | ConvertFrom-JSON ).selected
                } else {
                    throw ( $response | Format-List -Force | Out-String )
                }
            }

            $script:jsWebService
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
