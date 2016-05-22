# JobScheduler PowerShell Command Line Interface

The JobScheduler Command Line Interface (JCLI) can be used to control
JobScheduler instances (start, stop, status) and job-related objects
such as jobs, job chains, orders, tasks.

The JobScheduler CLI module supports Windows PowerShell 2.0 and newer.

# Purpose

The JobScheduler Command Line Interface is used for the following 
areas of operation:

* work as a replacement for the command script .\bin\jobscheduler.cmd:
  * provide operations for installing and removing the JobScheduler Windows service
  * starting and stopping JobScheduler instances including active and passive clusters
* provide bulk operations:
  * select jobs, job chains, orders and tasks
  * manage orders with operations for start, stop and removal
  * terminate tasks
* schedule jobs and orders:
  * add orders to job chains
  * start jobs
 
Find more information and documentation of cmdlets at [PowerShell Command Line Interface](https://kb.sos-berlin.com/x/cID4)

# Getting Started

## Prerequisites

### Check Execution Policy

* `PS C:\> Get-ExecutionPolicy`
 * shows the current execution policy, see e.g. [Microsoft Technet about_Execution_Policies](https://technet.microsoft.com/en-us/library/hh847748.aspx)
 * The required PowerShell execution policy for the JobScheduler CLI module is *RemoteSigned* or *Unrestricted*
* `PS C:\> Set-ExecutionPolicy RemoteSigned`
 * Modifying the execution policy might require administrative privileges

### Check Module Location

* PowerShell provides a number of locations for modules, see $env:PSModulePath for predefined module locations.
* Download/unzip the JobScheduler CLI module 
 * either to a user's module location such as `C:\Users\sosap\Documents\WindowsPowerShell\Modules\`
 * or to a location that is available for all users, e.g. `C:\Windows\system32\WindowsPowerShell\v1.0\Modules\`
 * or to an arbitrary location that later on is specified when importing the module.
* Directory names might differ according to PowerShell versions.
* The required JobScheduler CLI module folder name is *JobScheduler*. If you download the module it is wrapped in a folder that specifies the current branch, e.g. *scheduler-cli-powershell-1.0.0*. Manually create the *JobScheduler* folder in the module location and add the contents of the *scheduler-cli-powershell-1.0.0* folder from the archive.

## Import Module

* `PS C:\> Import-Module JobScheduler`
  * loads the module from a location that is available with the PowerShell module path, see $env:PSModulePath for predefined module locations.
* `PS C:\> Import-Module C:\some_path\JobScheduler`
  * loads the module from a specific location.

Hint: you can add the `Import-Module` command to your PowerShell user profile to have the module imported on start up of any PowerShell session.

## Use a JobScheduler Master 

As a first operation after importing the module it is required to execute the Use-Master cmdlet:

* `PS C:\> Use-Master <Url>`  or  `PS C:\> Use-Master -Url <Url>`
 * specifies the URL for which the JobScheduler Master is available. This is the same URL that you would use when opening the JOC GUI in your browser, e.g. `http://localhost:4444`. Do not omit the protocol (http/https) for the URL.
 * allows to execute cmdlets for the specified Master independently from the server and operating system that the JobScheduler Master is operated for, i.e. you can use PowerShell cmdlets to manage a JobScheduler Master running on a Linux box.
 * specifying the URL is not sufficient to manage the Windows Service of the respective Master, see below.
* `PS C:\> Use-Master -Id <JobSchedulerID>`
 * references the JobScheduler ID that has been assigned during installation of a Master. 
 * adds the JobScheduler ID to the assumed installation base path. A typical installation path would be `C:\Program Files\sos-berlin.com\jobscheduler\scheduler1.10` with `scheduler1.10` being the JobScheduler ID.
* `PS C:\> Use-Master -InstallPath <InstallationPath>`
 * specifies the full installation path, e.g. `C:\Program Files\sos-berlin.com\jobscheduler\scheduler1.10`, for a locally available JobScheduler Master.
* `PS C:\> Use-Master <Url> <JobSchedulerID>`
 * specify both URL and JobScheduler ID (recommended). 
 * determines if the Master with the specified *JobSchedulerID* is locally available.

## Run Commands

* `PS C:\> Show-Status`
  * shows the summary information of a JobScheduler Master.
* `PS C:\> (Get-Job).count`
  * shows the number of jobs that are available.
* `PS C:\> (Get-Task).count`
  * shows the number of tasks that are currently running.
* `PS C:\> Get-Job /sos | Get-Task | Stop-Task`
  * stops all running tasks from the specified folder.
* `PS C:\> $orders = Get-Order /sos`
  * collects the list of orders from a directory and stores it in a variable.
* `PS C:\> $orders = ( Get-Order /my_jobs -NoPermanent | Suspend-Order )`
  * retrieves temporary ad hoc orders from the *my_jobs* directory and any subfolders.
  * all temporary orders are suspended and the list of order objects is stored in a variable.
* `PS C:\> Get-Command -Module JobScheduler`
  * provides the complete list of cmdlets.
* `PS C:\> Get-Help Get-Task -detailed`
  * displays help information for each cmdlet.
 
# Further Reading

* [PowerShell Command Line Interface - Introduction](https://kb.sos-berlin.com/x/cID4)
* [PowerShell Command Line Interface - Cmdlets](https://kb.sos-berlin.com/x/aID4)
