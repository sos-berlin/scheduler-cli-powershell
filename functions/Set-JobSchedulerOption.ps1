function Set-JobSchedulerOption
{
<#
.SYNOPSIS
Set options for the JobScheduler CLI.

.PARAMETER DebugMaxOutputSize
When using $DebugPreference settings then the JobScheduler CLI provides the
XML documents of JobScheduler responses for inspection. Such responses are written to the
console window if their size does not exceed the max. output size.

Should the max. output size be exceeded then XML responses are written to temporary
files and a console debug message indicates the location of the respective file.
 
This cmdlet allows to set the max. output size to an individual value.

Default: 1000 Byte
#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $DebugMaxOutputSize=1000
)
    Process 
    {
		if ( $DebugMaxOutputSize )
		{
			$SCRIPT:jsOptionDebugMaxOutputSize = $DebugMaxOutputSize
		}
	}
}

Set-Alias -Name Set-Option -Value Set-JobSchedulerOption
