function Send-JobSchedulerWebServiceCommand
{
<#
.SYNOPSIS
Sends an XMl command to the JobScheduler Web Service.

.DESCRIPTION
JobScheduler Web Service supports a number of XML commands.
This cmdlet accepts XML commands and forwards them to the JobScheduler Master.

.PARAMETER Command
Specifies the XML command to be executed, e.g. <show_state/>

.Parameter Headers
A hashmap can be specified with name/value pairs for HTTP headers.

.OUTPUTS
This cmdlet returns the XML object of the JobScheduler response.

.EXAMPLE
$stateXml = Send-JobSchedulerWebServiceCommand '<show_state/>'

Returns summary information and inventory of jobs and job chains.

.EXAMPLE
$stateXml = Send-JobSchedulerWebServiceCommand '<show_state/>' @{'Cache-Control'='no-cache'}

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
        
        $commandUrl = $jsWebService.Url.scheme + '://' + $jsWebService.Url.Authority + '/joc/api/jobscheduler/command'
        $commandBody = "<jobscheduler_command jobschedulerId='$($jsWebService.ID)'>$($Command)</jobscheduler_command>"
        
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($commandUrl)"
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command: $commandBody"
        
        Send-JobSchedulerWebServiceRequest -Url $commandUrl -Method 'POST' -ContentType 'application/xml' -Body $commandBody -Headers $Headers
    }
}
