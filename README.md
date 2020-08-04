# JobScheduler PowerShell Command Line Interface

The JobScheduler Command Line Interface (CLI) can be used to control
JobScheduler instances (start, stop, status) and job-related objects
such as jobs, job chains, orders, tasks.

The JobScheduler CLI module supports Windows PowerShell FullCLR 5.1 and PowerShell CoreCLR 6.x and 7.x for Windows, Linux and MacOS environments.

# Purpose

The JobScheduler Command Line Interface is used for the following 
areas of operation:

* provide bulk operations:
    * select jobs, job chains, orders and tasks
    * manage orders with operations for start, stop and removal
    * suspend and resume jobs, job chains and orders
    * terminate tasks
* schedule jobs and orders:
    * add orders to job chains
    * start jobs
* manage Agents:
    * retrieve Agent clusters
    * check Agent status
* work as a replacement for existing Windows command scripts:
    * JobScheduler start script `.\bin\jobscheduler.cmd`:
        * provide operations for installing and removing the JobScheduler Windows service
        * starting and stopping JobScheduler instances including active and passive clusters
    * JobScheduler Event script `.\bin\jobscheduler_event.cmd`
 
Find more information and documentation of cmdlets at [PowerShell Command Line Interface](https://kb.sos-berlin.com/x/0wX3Ag)

# Getting Started

## Prerequisites

### Check Execution Policy

* `PS > Get-ExecutionPolicy`
 * shows the current execution policy, see e.g. [Microsoft Technet about_Execution_Policies](https://technet.microsoft.com/en-us/library/hh847748.aspx)
 * The required PowerShell execution policy for the JobScheduler CLI module is *RemoteSigned* or *Unrestricted*
* `PS > Set-ExecutionPolicy RemoteSigned`
 * Modifying the execution policy might require administrative privileges

### Check Module Location

* PowerShell provides a number of locations for modules, see $env:PSModulePath for predefined module locations.
* Download/unzip the JobScheduler CLI module 
 * either to a user's module location, e.g. for Windows `C:\Users\<user-name>\Documents\WindowsPowerShell\Modules\` or `/home/<user-name>/.local/share/powershell/Modules` for a Linux environment
 * or to a location that is available for all users, e.g. `C:\Windows\system32\WindowsPowerShell\v1.0\Modules\`
 * or to an arbitrary location that later on is specified when importing the module.
* Directory names might differ according to PowerShell versions.
* The required JobScheduler CLI module folder name is *JobScheduler*. If you download the module it is wrapped in a folder that specifies the current branch, e.g. *scheduler-cli-powershell-1.2.0*. Manually create the *JobScheduler* folder in the module location and add the contents of the *scheduler-cli-powershell-1.2.0* folder from the archive.

## Import Module

* `PS > Import-Module JobScheduler`
  * loads the module from a location that is available with the PowerShell module path, see $env:PSModulePath for predefined module locations.
* `PS > Import-Module C:\some_path\JobScheduler`
  * loads the module from a specific location.

Hint: you can add the `Import-Module` command to your PowerShell user profile to have the module imported on start up of a PowerShell session.

## Use Web Service

As a first operation after importing the module it is recommended to execute the Connect-JS cmdlet:

* `PS > Connect-JS <Url> -AskForCredentials`
 * specifies the URL of JOC Cockpit, e.g. http://localhost:4446, and aks interactively for credentials. The default acount is `root` with the password `root`.
* `PS > Connect-JS <Url> <Credentials> <JobSchedulerId>`  or  `PS > Connect-JS -Url <Url> -Credentials <Credentials> -Id <JobSchedulerId>`
 * specifies the URL for which JOC Cockpit is available. This is the same URL that you would use when opening the JOC Cockpit GUI in your browser, e.g. `http://localhost:4446`. When omitting the protocol (http/https) for the URL then http is assumed.
 * specifies the ID that a JobScheduler Master has been installed with. As JOC Cockpit can manage a number of Master instances the `-Id` parameter can be used to select the respective Master.
 * specifies the credentials (user account and password) that are used to connect to the Web Service.
   * A credential object can be created by keyboard input like this:
     * `Set-JSCredentials -AskForCredentials`
   * A credential object can be created like this:
     * `$credentials = ( New-Object -typename System.Management.Automation.PSCredential -ArgumentList 'root', ( 'root' | ConvertTo-SecureString -AsPlainText -Force) )`
     * The example makes use of the default account "root" and password "root".
     * A possible location for the above code is a user's PowerShell Profile that would be executed for a PowerShell session.
   * Credentials can be forwarded with the Url parameter like this: 
     * `Connect-JS -Url http://root:root@localhost:4446 -Id jobscheduler`
     * Specifying account and password with a URL is considered insecure.
 * allows to execute cmdlets for the specified JobScheduler Master independently from the server and operating system that the  Master is operated for, i.e. you can use PowerShell cmdlets on Windows to manage a JobScheduler Master running e.g. on a Linux box and vice versa.
 * specifying the URL is not sufficient to connect to the Windows Web Service of a Master, see below.

## Run Commands

The JobScheduler CLI provides a number of cmdlets, see [PowerShell CLI - Cmdlets](https://kb.sos-berlin.com/x/1QX3Ag). Return values of cmdlets generally correspond to the JOC Cockpit [REST Web Service](http://test.sos-berlin.com/JOC/raml-doc/JOC-API).

* `PS > Get-Command -Module JobScheduler`
    * The complete list of cmdlets is available with this command.
* `PS > Get-JobSchedulerStatus`
    * Cmdlets come with a full name that includes the term JobScheduler.
* `PS > Get-JSStatus`
    * The term JobScheduler can be abbreviated to JS.
* `PS > Get-Status`
    * The term JobScheduler can further be omitted if the resulting alias does not conflict with existing cmdlets.
    * To prevent conflicts with existing cmdlets from other modules no conflicting aliases are created. This includes aliases for cmdlets from the PowerShell Core as e.g. Get-Job, Start-Job, Stop-Job etc. and cmdlets from other modules loaded prior to the JobScheduler CLI.
* `PS > Get-Help Get-JSStatus -detailed`
  * displays help information for the given cmdlet.

# Examples

* `PS > Get-JSStatus -Display`
  * shows the summary information for a JobScheduler Master.
* `PS > (Get-JSJobChain).count`
  * shows the number of job chains that are available.
* `PS > (Get-JSJob).count`
  * shows the number of jobs that are available.
* `PS > (Get-JSTask).count`
  * shows the number of tasks that are currently running.
* `PS > Get-JSJob -Directory /sos -Running | Stop-JSTask`
  * stops all running tasks from the specified folder.
* `PS > Get-JSJob -Running -Enqueued | Stop-JSTask`
  * performs and emergency stop and kills all running and enqueued tasks.
* `PS > Get-JSTask -Enqueued | Stop-JSTask`
  * retrieves the list of scheduled tasks, i.e. tasks that are scheduled for later start.
* `PS > $orders = ( Get-JSOrder -Directory /my_jobs -Recursive -Temporary | Suspend-JSOrder )`
  * retrieves temporary ad hoc orders from the *my_jobs* directory and any sub-folders with orders found being suspended. The list of affected orders is returned.
* `PS > $orders | Remove-JSOrder`
  * remove orders based on a list that has previously been retrieved.

# Manage Log Output

JobScheduler cmdlets consider verbosity and debug settings.

* `PS > $VerbosePreference = "Continue"`
    * This will cause verbose output to be created from cmdlets.
* `PS > $VerbosePreference = "SilentlyContinue"`
    * The verbosity level is reset.
* `PS > $DebugPreference = "Continue"`
    * This will cause debug output to be created from cmdlets.
* `PS > $DebugPreference = "SilentlyContinue"`
    * The debug level is reset.
 
# Further Reading

* [PowerShell Command Line Interface - Introduction](https://kb.sos-berlin.com/x/0wX3Ag)
* [PowerShell Command Line Interface - Use Cases](https://kb.sos-berlin.com/x/Wwf3Ag)
* [PowerShell Command Line Interface - Cmdlets](https://kb.sos-berlin.com/x/1QX3Ag)
