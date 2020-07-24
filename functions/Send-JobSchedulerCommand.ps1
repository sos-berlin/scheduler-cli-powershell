function Send-JobSchedulerCommand
{
<#
.SYNOPSIS
Sends an XMl command to the JobScheduler Master.

.DESCRIPTION
JobScheduler Master supports a number of XML commands.
This cmdlet accepts XML commands and forwards them to the JobScheduler Master.

.PARAMETER Command
Specifies the XML command to be executed, e.g. <show_state/>

.Parameter Headers
A hashmap can be specified with name/value pairs for HTTP headers.

.OUTPUTS
This cmdlet returns the XML object of the JobScheduler response.

.EXAMPLE
$stateXml = Send-JobSchedulerCommand '<show_state/>'

Returns summary information and inventory of jobs and job chains.

.EXAMPLE
$stateXml = Send-JobSchedulerCommand '<show_state/>' @{'Cache-Control'='no-cache'}

Returns summary information including the inventory while using individual HTTP headers.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Command,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $Headers = @{}
)

    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
    }

    Process
    {
        if ( !$Command )
        {
            throw "$($MyInvocation.MyCommand.Name): no XML command specified, use -Command"
        }
        
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Url)"
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command: $Command"
        
#       Send-JobSchedulerXMLCommand -Url $js.Url -Command $Command -Headers $Headers
        Invoke-JobSchedulerWebRequestXmlCommand -Command $Command -Headers $Headers
        
    }
}
