function Set-JobSchedulerCredentials
{
<#
.SYNOPSIS
When sending requests to a JobScheduler Master then authentication might be required.

.PARAMETER UseDefaultCredentials
Specifies that the implicit Windows credentials of the current user are applied for authentication challenges.

.PARAMETER AskForCredentials
Specifies that the user is asked for the account and password that are used for authentication with JobScheduler.

.PARAMETER Credentials
Specifies that a credentials object is used that is assigned to this parameter.

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
    [System.Management.Automation.PSCredential] $Credentials
)
    Process 
    {
        if ( $UseDefaultCredentials -and $Credentials )
        {
            throw "$($MyInvocation.MyCommand.Name): Use just one of the parameters -UseDefaultCredentials and -Credentials"
        }
    
        $SCRIPT:jsOptionWebRequestUseDefaultCredentials = $UseDefaultCredentials
        $SCRIPT:jsCredentials = $Credentials
    
        if ( $AskForCredentials )
        {
            Write-Host "* ************************************************** *"
            Write-Host "* JobScheduler requires credentials for web access:  *"
            Write-Host "* enter account and password for authentication      *"
            Write-Host "* ************************************************** *"
            $account = Read-Host "Enter user account for JobScheduler access: "
            $password = Read-Host "Enter password for JobScheduler access: " -AsSecureString
            $SCRIPT:jsCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $account, $password
        }
    }
}

Set-Alias -Name Set-Credentials -Value Set-JobSchedulerCredentials
