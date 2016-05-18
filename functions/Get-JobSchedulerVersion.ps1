function Get-JobSchedulerVersion
{
<#
.SYNOPSIS
Returns the JobScheduler Master version

.DESCRIPTION
The cmdlet returns the version of the JobScheduler Master.

.EXAMPLE
Get-Version

Returns the JobScheduler version.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
)
	Begin
	{
		Approve-JobSchedulerCommand $MyInvocation.MyCommand
	}
	
    Process
    {
		$arguments = "-ini=$(($js.Config.FactoryIni).Replace( '/', '\' )) -config=$($js.Config.SchedulerXml) -V"						
		Write-Host ".. $($MyInvocation.MyCommand.Name): executing version command: $($js.Install.ExecutableFile) $($arguments)"

		$process = Start-Process -FilePath """$($js.Install.ExecutableFile)""" "$($arguments)" -PassThru 
    }
}

Set-Alias -Name Get-Version -Value Get-JobSchedulerVersion
