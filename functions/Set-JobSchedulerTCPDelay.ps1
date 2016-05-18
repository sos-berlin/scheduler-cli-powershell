function Set-JobSchedulerTCPDelay( [int] $TCPReadDelay=100, [int] $TCPWriteDelay=100 )
{
<#
.SYNOPSIS

For TCP communication network latency has to be considered that might vary
depending on infrastructure constraints.

* A read delay is applied in order to wait for JobScheduler responses to be delivered.
* A write delay is applied in order to guarantee acceptance of previous commands.

Should the default values not match the infrastructure performance then the
read and write delays for TCP communication can be adjusted.
 
.PARAMETER TCPReadDelay
When sending commands a delay is applied to wait for the respective response.
Due to network latency or high JobScheduler load the delay might have to be increased.

Default: 100 ms

.PARAMETER TCPWriteDelay
When sending commands then a delay is applied to wait for any outstanding responses.
Due to network latency or high JobScheduler load the delay might have to be increased.

Default: 100 ms

#>

	$SCRIPT:jsTCPReadDelay = $TCPReadDelay
	$SCRIPT:jsTCPWriteDelay = $TCPWriteDelay
}

Set-Alias -Name Set-TCPDelay -Value Set-JobSchedulerTCPDelay
