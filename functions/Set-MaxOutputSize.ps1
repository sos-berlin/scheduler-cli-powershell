function Set-JobSchedulerMaxOutputSize( [int] $size )
{
<#
.SYNOPSIS

When using $DebugPreference settings then the JobScheduler CLI provides the
XML documents of JobScheduler responses. Such responses are written to the
console window if their size does not exceed the max. output size.

Should the max. output size be exceeded then XML responses are written to temporary
files and a console debug message indicates the location of the respective file.
 
This function allows to set the max. output size to an individual value.

Default: 1000 Byte
#>

	$SCRIPT:jsDebugMaxOutputSize = $size
}

Set-Alias -Name Set-MaxOutputSize -Value Get-JobSchedulerMaxOutputSize


