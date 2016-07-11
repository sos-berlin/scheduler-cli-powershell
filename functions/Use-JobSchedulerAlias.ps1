function Use-JobSchedulerAlias
{
<#
.SYNOPSIS
This cmdlet creates alias names for JobScheduler cmdlets.

.DESCRIPTION
To create aliases this cmdlet has to be dot sourced, i.e. use

* . Use-JobSchedulerAlias -Prefix JS: works as expected
* Use-JobSchedulerAlias-Prefix JS: has no effect

When using a number of modules from different vendors then naming conflicts might occur
for cmdlets with the same name from different modules.

The JobScheduler CLI makes use of the following policy:

* All cmdlets use a unique qualifier for the module as e.g. Use-JobSchedulerMaster, Get-JobSchedulerInventory etc.
* Users can use this cmdlet to create a short notation for cmdlet alias names. Two flavors are offered:
** use a shorthand notation as e.g. Use-JSMaster instead of Use-JobSchedulerMaster. This notation is recommended as is suggests fairly unique names.
** use a shorthand notation as e.g. Use-Master instead of Use-JobSchedulerMaster. This notation can conflict with cmdlets of the PowerShell Core, e.g. for Start-Job, Stop-Job
* Users can exclude shorthand notation for specific cmdlets by use of an exclusion list.

You can find the resulting aliases by use of the command Get-Command -Module JobScheduler.

.PARAMETER Prefix
Specifies the prefix that is used for a shorthand notation, e.g.

* the parameter -Prefix "JS" creates an alias Use-JSMaster for Use-JobSchedulerMaster
* the parameter -Prefix without a value assigned creates an alias Use-Master for Use-JobSchedulerMaster

By default aliases are created for both the prefix "JS" and with no prefix being assigned which results in the following possible notation:

* Use-JobSchedulerMaster
* Use-JSMaster
* Use-Master

.PARAMETER Excludes
Specifies a list of resulting alias names that are excluded from alias creation.

When using e.g. Use-JobSchedulerAlias -Prefix without a prefix being assigned then
- at the time of writing - the following aliases would conflict with cmdlet names from the PowerShell Core

* Get-Job
* Start-Job
* Stop-Job

Default: -Excludes Get-Job,Start-Job,Stop-Job

.PARAMETER ExludesPrefix
Specifies a prefix that is used should a resulting alias be a member of the list of 
exlcuded aliases that is specified with the -Excludes parameter

.PARAMETER NoDuplicates
This parameters specifies that no aliases should be created that conflict with existing cmdlets, functions or aliases.

.EXAMPLE
. Use-JobSchedulerAlias -Prefix JS

Creates aliases for all JobScheduler CLI cmdlets that allow to use e.g. Use-JSMaster for Use-JobSchedulerMaster

.EXAMPLE
. Use-JobSchedulerAlias -Prefix -Exclude Get-Job,Start-Job,Stop-Job -ExcludePrefix JS

Creates aliases for all JobScheduler CLI cmdlets that allow to use e.g. Use-Master for Use-JobSchedulerMaster.
This is specified by the -Prefix parameter without a value being assigned.

For the resulting alias names Get-Job, Start-Job and Stop-Job the alias names
Get-JSJob, Start-JSJob and Stop-JSJob are created by use of the -ExcludePrefix "JS" parameter.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Prefix,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string[]] $Excludes,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ExcludesPrefix,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $NoDuplicates
)
    Process
    {
		if ( $NoDuplicates )
		{
			$allCommands = Get-Command | Select-Object -Property Name | foreach { $_.Name }
		}
		
        $commands = Get-Command -Module JobScheduler -CommandType 'Function'
        foreach( $command in $commands )
        {
            $aliasName = $command.name.Replace( '-JobScheduler', "-$($Prefix)" )

            if ( $Excludes -contains $aliasName )
            {
                if ( $ExcludesPrefix )
                {
                    $aliasName = $command.name.Replace( '-JobScheduler', "-$($ExcludesPrefix)" )
                } else {
                    continue
                }
            }
			
			if ( $NoDuplicates )
			{
				$allCommands = Get-Command
				if ( $allCommands -contains $aliasName ) 
				{
					continue
				}
			}
            
            Set-Alias -Name $aliasName -Value $command.Name
        }
        
        Export-ModuleMember -Alias "*"
    }    
}
