function Set-JobSchedulerCredentials
{
<#
.SYNOPSIS
Sets credentials that are used to authenticate with requests to the JobScheduler Web Services.

.DESCRIPTION
Credentials are required to authenticate with the JobScheduler Web Service.
Such credentials can be specified on-the-fly with the Connect-JobScheduler cmdlet or
they can be specified with this cmdlet.

.PARAMETER UseDefaultCredentials
Specifies that the implicit Windows credentials of the current user are applied for authentication challenges.

Either the parameter -UseDefaultCredentials or -Credentials can be used.

.PARAMETER AskForCredentials
Specifies that the user is prompted for the account and password that are used for authentication with JobScheduler.

.PARAMETER Credentials
Specifies a credentials object that is used for authentication with JobScheduler.

A credentials object can be created e.g. with:

    $account = 'John'
    $password = ( 'Doe' | ConvertTo-SecureString -AsPlainText -Force)
    $credentials = New-Object -typename System.Management.Automation.PSCredential -Argumentlist $account, $password

An existing credentials object can be retrieved from the Windows Credential Manager e.g. with:

    $systemCredentials = Get-JobSchedulerSystemCredentials -TargetName 'localhost'
    $credentials = ( New-Object -typename System.Management.Automation.PSCredential -Argumentlist $systemCredentials.UserName, $systemCredentials.Password )

Either the parameter -UseDefaultCredentials or -Credentials can be used.

.PARAMETER ProxyUseDefaultCredentials
Specifies that the implicit Windows credentials of the current user are applied for proxy authentication.

Either the parameter -ProxyUseDefaultCredentials or -ProxyCredentials can be used.

.PARAMETER ProxyAskForCredentials
Specifies that the user is prompted for the account and password that are used for authentication with a proxy.

.PARAMETER ProxyCredentials
Specifies a credentials object that is used for authentication with a proxy. See parameter -Credentials how to create a credentials object.

Either the parameter -ProxyUseDefaultCredentials or -ProxyCredentials can be used.

.EXAMPLE
Set-JobSchedulerCredentials -UseDefaultCredentials

The implicit Windows credentials are used for authentication. No password is used or stored in memory.

.EXAMPLE
Set-JobSchedulerCredentials -AskForCredentials

Specifies that the user is prompted for account and password. The password is converted to a secure string
and a credentials object is created for authentication.

.EXAMPLE
$account = 'John'
$password = ('Doe' | ConvertTo-SecureString -AsPlainText -Force)
$credentials = New-Object -typename System.Management.Automation.PSCredential -ArgumentList $account, $password
Set-JobSchedulerCredentials -Credentials $credentials

An individual credentials object is created that is assigned the -Credentials parameter.
.EXAMPLE
$account = 'John'
$password = Read-Host 'Enter password for John: ' -AsSecureString
$credentials = New-Object -typename System.Management.Automation.PSCredential -ArgumentList $account, $password
Set-JobSchedulerCredentials -Credentials $credentials

An individual credentials object is created that is assigned the -Credentials parameter.
#>
[cmdletbinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $UseDefaultCredentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $AskForCredentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Management.Automation.PSCredential] $Credentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $ProxyUseDefaultCredentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $ProxyAskForCredentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Management.Automation.PSCredential] $ProxyCredentials
)
    Process
    {
        if ( $UseDefaultCredentials -and $Credentials )
        {
            throw "$($MyInvocation.MyCommand.Name): Use just one of the parameters -UseDefaultCredentials or -Credentials"
        }

        if ( $ProxyUseDefaultCredentials -and $ProxyCredentials )
        {
            throw "$($MyInvocation.MyCommand.Name): Use just one of the parameters -ProxyUseDefaultCredentials or -ProxyCredentials"
        }

        if ( $UseDefaultCredentials )
        {
            $script:jsOptionWebRequestUseDefaultCredentials = $UseDefaultCredentials
            $script:jsWebServiceOptionWebRequestUseDefaultCredentials = $UseDefaultCredentials
        } else {
            $script:jsOptionWebRequestUseDefaultCredentials = $false
            $script:jsWebServiceOptionWebRequestUseDefaultCredentials = $false
        }

        if ( $Credentials )
        {
            $script:jsCredential = $Credentials
            $script:jsWebServiceCredential = $Credentials
        }

        if ( $AskForCredentials )
        {
            Write-Output '* ***************************************************** *'
            Write-Output '* JobScheduler credentials for web access:              *'
            Write-Output '* enter account and password for authentication         *'
            Write-Output '* ***************************************************** *'
            $account = Read-Host 'Enter user account for JobScheduler web access: '

            if ( $account )
            {
                $password = Read-Host 'Enter password for JobScheduler web access: ' -AsSecureString

                if ( $PSCmdlet.ShouldProcess( 'jsCredential' ) )
                {
                    $script:jsCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $account, $password
                    $script:jsWebServiceCredential = $script:jsCredential
                }
            }
        }

        if ( $ProxyUseDefaultCredentials )
        {
            $script:jsOptionWebRequestProxyUseDefaultCredentials = $ProxyUseDefaultCredentials
            $script:jsWebServiceOptionWebRequestProxyUseDefaultCredentials = $ProxyUseDefaultCredentials
        } else {
            $script:jsOptionWebRequestProxyUseDefaultCredentials = $false
            $script:jsWebServiceOptionWebRequestProxyUseDefaultCredentials = $false
        }

        if ( $ProxyCredentials )
        {
            $script:jsProxyCredential = $ProxyCredentials
            $script:jsWebServiceProxyCredential = $ProxyCredentials
        }

        if ( $ProxyAskForCredentials )
        {
            Write-Output '* ***************************************************** *'
            Write-Output '* JobScheduler credentials for proxy access:              *'
            Write-Output '* enter account and password for proxy authentication   *'
            Write-Output '* ***************************************************** *'
            $proxyAccount = Read-Host 'Enter user account for JobScheduler proxy access: '

            if ( $proxyAccount )
            {
                $proxyPassword = Read-Host 'Enter password for JobScheduler proxy access: ' -AsSecureString

                if ( $PSCmdlet.ShouldProcess( 'jsProxyCredential' ) )
                {
                    $script:jsProxyCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $proxyAccount, $proxyPassword
                    $script:jsWebServiceProxyCredential = $script:jsProxyCredentials
                }
            }
        }
    }
}
