function Start-JobSchedulerExecutableFile
{
<#
.SYNOPSIS
Starts an executable file in a Windows OS with parameters optionally for a different user account.

.DESCRIPTION
Runs the specified executable file in the context of a different user account for a Windows OS.
The cmdlet reads credentials from the Windows Credential Manager, i.e. credentials
that have previously been added by the Windows command "cmdkey" or any other credential management tools.
Credentials are indicated by their "target" name which represents the identifier by which
credentials are retrieved.

By default a user profile is considered. The -NoLoadUserProfile parameter prevents using a profile.

The cmdlet returns a [System.Diagnostics.Process] object that includes additional properties:

* By default
** output to stdout is available with the "StandardOutputContent" property.
** output to stderr is available with the "StandardErrorContent" property.

* With the parameters -NoStandardOutput and -NoStandardError respectively being used
** output to stdout is available from a temporary file that is indicated with the "StandardOutputFile" property.
** output to stderr is available from a temporary file that is indicated with the "StandardErrorFile" property.

* An exit code is not reliably reported if the cmdlet is used from an unprivileged account
  to start a process for a different user 

.PARAMETER Path
Specifies the full path and name of the executable file to be started. Executable files includes binary files (.com, .exe) 
and command scripts (.cmd, .bat) etc..

.PARAMETER Argumentlist
Specifies the arguments for starting the executable file.

.PARAMETER TargetName
Specifies the target name for credentials that have been added prior to execution of the file.

Target names for credentials can be added e.g. by use of the "cmdkey" command with the account that JobScheduler is operated for:

    C:\> cmdkey /add:run_as_ap /user:ap /pass:ap
    
The command adds credentials for the account "ap" with password "ap" and specifies the target name "run_as_ap".
In addition to built-in Windows commands a vast number of tools is available for credentials management.

Using the target name "run_as_ap" allows to run the executable file for the specified user account.

.PARAMETER NoLoadUserProfile
Specifies that the profile of the user account that the executable file is running for should not be executed.
This includes that environment variables at user level are not available for the executable file.

.PARAMETER NoStandardOutput
Specifies that the output of the executable file is not returned with the resulting process object.
Instead the name of a temporary file is returned.

The resulting process object includes the "StandardOutputFile" property
that indicates the temporary file that contains the output to stdout.

.PARAMETER NoStandardError
Specifies that the output of the executable file is not returned with the resulting process object.
Instead the name of a temporary file is returned.

The resulting process object includes the "StandardErrorFile" property
that indicates the temporary file that contains the output to stderr.

.OUTPUTS
The cmdlet returns a [System.Diagnostics.Process] object that includes additional properties:

* By default
** output to stdout is available with the "StandardOutputContent" property.
** output to stderr is available with the "StandardErrorContent" property.
* With the parameters -NoStandardOutput and -NoStandardError respectively being used
** output to stdout is available from a temporary file that is indicated with the "StandardOutputFile" property.
** output to stderr is available from a temporary file that is indicated with the "StandardErrorFile" property.

.EXAMPLE
$process = Start-JobSchedulerExecutableFile -Path 'c:/tmp/powershell/sample_script.cmd' -TargetName 'run_as_ap'

Runs the command script for the account that is specified with the credentials identified by the target name.

The resulting process object includes the properties 

    * $process.StandardOutputContent
    * $process.StandardErrorContent

that contain the output that is created to stdout and stderr.

.EXAMPLE
$process = Start-JobSchedulerExecutableFile -Path 'c:/tmp/powershell/sample_script.cmd' -TargetName 'run_as_ap' -NoStandardOutput -NoStandardError

Runs the command script for the account that is specified with the credentials identified by the target name.

The resulting process object includes the properties 

    * $process.StandardOutputFile
    * $process.StandardErrorFile

that indicate temporary files that contain the output that is created to stdout and stderr.

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Path,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Argumentlist,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $TargetName,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $NoStandardOutput,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $NoStandardError,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $NoLoadUserProfile
)
    Begin
    {
        $stopWatch = Start-StopWatch
        $process = $null
        
        if ( !$isWindows )
        {
            throw "$($MyInvocation.MyCommand.Name): cmdlet can be used with Windows OS only"
        }
    }
        
    Process
    {
        $tempStdoutFile = [IO.Path]::GetTempFileName()
        $tempStderrFile = [IO.Path]::GetTempFileName()

        Write-Debug ".. $($MyInvocation.MyCommand.Name): using temporary file for stdout: $($tempStdoutFile)"
        Write-Debug ".. $($MyInvocation.MyCommand.Name): using temporary file for stderr: $($tempStderrFile)"
    
        try
        {
            if ( $TargetName )
            {
                $systemCredentials = Get-JobSchedulerSystemCredentials -TargetName $TargetName
                if ( !$systemCredentials )
                {
                    throw "$($MyInvocation.MyCommand.Name): no credentials found for target name: $($TargetName)"
                }
    
                $credentials = ( New-Object -TypeName System.Management.Automation.PSCredential -Argumentlist $systemCredentials.UserName, $systemCredentials.Password )
                if ( !$credentials )
                {
                    throw "$($MyInvocation.MyCommand.Name): could not use credentials for target name: $($TargetName)"
                }
    
                if ( $NoLoadUserProfile )
                {
#                   -Wait has to be dropped as it throws "access denied" when used with credentials, dropping -Wait prevents the exit code from being provided, we have to live with that
#                   $process = Start-Process -FilePath 'cmd.exe' "/c ""`"$Path`" $Argumentlist"" " -NoNewWindow -PassThru -Wait -Credential $credentials -RedirectStandardOutput $tempStdoutFile -RedirectStandardError $tempStderrFile
                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): running executable file without profile for user account '$($systemCredentials.UserName)': cmd.exe /c `"$Path`" $Argumentlist"
                    $process = Start-Process -FilePath 'cmd.exe' "/c ""`"$Path`" $Argumentlist"" " -NoNewWindow -PassThru -Credential $credentials -RedirectStandardOutput $tempStdoutFile -RedirectStandardError $tempStderrFile
                } else {
#                   -Wait has to be dropped as it throws "access denied" when used with credentials, dropping -Wait prevents the exit code from being provided, we have to live with that
#                   $process = Start-Process -FilePath 'cmd.exe' "/c ""`"$Path`" $Argumentlist"" " -NoNewWindow -PassThru -Wait -Credential $credentials  -LoadUserProfile -RedirectStandardOutput $tempStdoutFile -RedirectStandardError $tempStderrFile
                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): running executable file with profile for user account '$($systemCredentials.UserName)': cmd.exe /c `"$Path`" $Argumentlist"
                    $process = Start-Process -FilePath 'cmd.exe' "/c ""`"$Path`" $Argumentlist"" " -NoNewWindow -PassThru -Credential $credentials  -LoadUserProfile -RedirectStandardOutput $tempStdoutFile -RedirectStandardError $tempStderrFile
                }
            } else {
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): running executable file for current user account: cmd.exe /c `"$Path`" $Argumentlist"
                $process = Start-Process -FilePath 'cmd.exe' "/c ""`"$Path`" $Argumentlist"" " -NoNewWindow -PassThru -Wait -RedirectStandardOutput $tempStdoutFile -RedirectStandardError $tempStderrFile
            }

            if ( $process )
            {
                $processHandle = $process.Handle

                if ( !$process.HasExited )
                {
                    $process.WaitForExit()
                }
    
                # not applicable in newer PowerShell versions >= 6
                # $process | Add-Member -Membertype NoteProperty -Force -Name ExitCode -Value $process.GetType().GetField("exitCode", "NonPublic,Instance").GetValue($process)
                
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): process terminated with exit code: $($process.ExitCode)"
        
                if ( $NoStandardOutput )
                {
                    $process | Add-Member -Membertype NoteProperty -Name StandardOutputFile -Value $tempStdoutFile
                } else {
                    $process | Add-Member -Membertype NoteProperty -Name StandardOutputContent -Value (Get-Content -Path $tempStdoutFile)
                }
                            
                if ( $NoStandardError )
                {
                    $process | Add-Member -Membertype NoteProperty -Name StandardErrorFile -Value $tempStderrFile
                } else {
                    $process | Add-Member -Membertype NoteProperty -Name StandardErrorContent -Value $(Get-Content -Path $tempStderrFile)
                }
            }
            
            $process
        } catch {
            throw ( $_.Exception | Format-List -Force | Out-String )
        } finally {
            if ( !$NoStandardOutput )
            {
                try
                {
                    Remove-Item -Path $tempStdoutFile
                } catch {
                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): could not remove temporary file for stdout: $tempStdoutFile"
                }
            }

            if ( !$NoStandardError )
            {
                try
                {
                    Remove-Item -Path $tempStderrFile
                } catch {
                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): could not remove temporary file for stderr: $tempStderrFile"
                }
            }
        }
    }

    End
    {
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}
