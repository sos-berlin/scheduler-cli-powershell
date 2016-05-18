function Set-JobSchedulerMaxOutputSize( [int] $MaxOutputSize=1000 )
{
<#
.SYNOPSIS

When using $DebugPreference settings then the JobScheduler CLI provides the
XML documents of JobScheduler responses for inspection. Such responses are written to the
console window if their size does not exceed the max. output size.

Should the max. output size be exceeded then XML responses are written to temporary
files and a console debug message indicates the location of the respective file.
 
This cmdlet allows to set the max. output size to an individual value.

.PARAMETER MaxOutputSize
Specifies the threshold value starting from which XML responses are 
written to temporary files instead of direct output in the console window.

Default: 1000 Byte
#>

	$SCRIPT:jsDebugMaxOutputSize = $MaxOutputSize
}

Set-Alias -Name Set-MaxOutputSize -Value Set-JobSchedulerMaxOutputSize
