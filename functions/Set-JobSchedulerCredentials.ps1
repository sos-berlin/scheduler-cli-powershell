function Set-JobSchedulerCredentials
{
<#
.SYNOPSIS
When sending requests to a JobScheduler Master then authentication might be required.

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
[cmdletbinding()]
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
            throw "$($MyInvocation.MyCommand.Name): Use just one of the parameters -UseDefaultCredentials and -Credentials"
        }

        if ( $ProxyUseDefaultCredentials -and $ProxyCredentials )
        {
            throw "$($MyInvocation.MyCommand.Name): Use just one of the parameters -ProxyUseDefaultCredentials and -ProxyCredentials"
        }
    
        $SCRIPT:jsOptionWebRequestUseDefaultCredentials = $UseDefaultCredentials
        $SCRIPT:jsCredentials = $Credentials
    
        if ( $AskForCredentials )
        {
            Write-Host '* ***************************************************** *'
            Write-Host '* JobScheduler credentials for web access:              *'
            Write-Host '* enter account and password for authentication         *'
            Write-Host '* ***************************************************** *'
            $account = Read-Host 'Enter user account for JobScheduler web access: '
            
            if ( $account )
            {
                $password = Read-Host 'Enter password for JobScheduler web access: ' -AsSecureString
                $SCRIPT:jsCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $account, $password
            }
        }

        $SCRIPT:jsOptionWebRequestProxyUseDefaultCredentials = $ProxyUseDefaultCredentials
        $SCRIPT:jsProxyCredentials = $ProxyCredentials

        if ( $ProxyAskForCredentials )
        {
            Write-Host '* ***************************************************** *'
            Write-Host '* JobScheduler credentials for proxy access:              *'
            Write-Host '* enter account and password for proxy authentication   *'
            Write-Host '* ***************************************************** *'
            $proxyAccount = Read-Host 'Enter user account for JobScheduler proxy access: '
            
            if ( $proxyAccount )
            {
                $proxyPassword = Read-Host 'Enter password for JobScheduler proxy access: ' -AsSecureString
                $SCRIPT:jsProxyCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $proxyAccount, $proxyPassword
            }
        }
    }
}
