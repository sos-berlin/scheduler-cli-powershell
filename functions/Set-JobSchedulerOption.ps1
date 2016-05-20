function Set-JobSchedulerOption( [int] $DebugMaxOutputSize=1000, [bool] $WebRequestUseDefaultCredentials=$true )
{
<#
.SYNOPSIS

.PARAMETER DebugMaxOutputSize
When using $DebugPreference settings then the JobScheduler CLI provides the
XML documents of JobScheduler responses for inspection. Such responses are written to the
console window if their size does not exceed the max. output size.

Should the max. output size be exceeded then XML responses are written to temporary
files and a console debug message indicates the location of the respective file.
 
This cmdlet allows to set the max. output size to an individual value.

Default: 1000 Byte

.PARAMETER WebRequestUseDefaultCredentials
When sending request to a JobScheduler Master then authentication might be required.
This parameter specifies that the credentials of the current user are applied for authentication challenges.
#>

	if ( $DebugMaxOutputSize )
	{
		$SCRIPT:jsOptionDebugMaxOutputSize = $DebugMaxOutputSize
	}

	if ( $WebRequestUseDefaultCredentials )
	{
		$SCRIPT:jsOptionWebRequestUseDefaultCredentials = $WebRequestUseDefaultCredentials
	}
}

Set-Alias -Name Set-Option -Value Set-JobSchedulerOption
