function Get-JobSchedulerSystemCredentials
{
<#
.SYNOPSIS
Gets a credentials object (PSCredential) from the Windows Credential Manager

.DESCRIPTION
This cmdlet will return a [PSCredential] object from a credential stored in Windows Credential Manager.
This cmdlet can only access Generic Credentials.

.PARAMETER TargetName
The name of the target login informations in the Windows Credential Manager

.EXAMPLE
PS C:\>Get-JobSchedulerSystemCredentials 'localhost'

UserName                             Password
--------                             --------
ap                                   System.Security.SecureString

.OUTPUTS
System.Management.Automation.PSCredential

.NOTES
To add credentials open up Control Panel>User Accounts>Credential Manager and click "Add a gereric credential".
The "Internet or network address" field will be the Name required by the Get-JobSchedulerSystemCredentials cmdlet.

Forked from https://gist.github.com/toburger/2947424 which was adapted from
http://stackoverflow.com/questions/7162604/get-cached-credentials-in-powershell-from-windows-7-credential-manager

.LINK
Set-JobSchedulerCredentials

.ROLE
Operations

.FUNCTIONALITY
Security

#>
[cmdletbinding()]
[OutputType([System.Management.Automation.PSCredential])]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [ValidateNotNullOrEmpty()]
    [Alias("Address", "Location", "Name")]
    [string] $TargetName
)

    Begin
    {
    }

    Process
    {
        $sig = @"

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct NativeCredential
{
    public UInt32 Flags;
    public CRED_TYPE Type;
    public IntPtr TargetName;
    public IntPtr Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public UInt32 CredentialBlobSize;
    public IntPtr CredentialBlob;
    public UInt32 Persist;
    public UInt32 AttributeCount;
    public IntPtr Attributes;
    public IntPtr TargetAlias;
    public IntPtr UserName;

    internal static NativeCredential GetNativeCredential(Credential cred)
    {
        NativeCredential ncred = new NativeCredential();
        ncred.AttributeCount = 0;
        ncred.Attributes = IntPtr.Zero;
        ncred.Comment = IntPtr.Zero;
        ncred.TargetAlias = IntPtr.Zero;
        ncred.Type = CRED_TYPE.GENERIC;
        ncred.Persist = (UInt32)1;
        ncred.CredentialBlobSize = (UInt32)cred.CredentialBlobSize;
        ncred.TargetName = Marshal.StringToCoTaskMemUni(cred.TargetName);
        ncred.CredentialBlob = Marshal.StringToCoTaskMemUni(cred.CredentialBlob);
        ncred.UserName = Marshal.StringToCoTaskMemUni(System.Environment.UserName);
        return ncred;
    }
}

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct Credential
{
    public UInt32 Flags;
    public CRED_TYPE Type;
    public string TargetName;
    public string Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public UInt32 CredentialBlobSize;
    public string CredentialBlob;
    public UInt32 Persist;
    public UInt32 AttributeCount;
    public IntPtr Attributes;
    public string TargetAlias;
    public string UserName;
}

public enum CRED_TYPE : uint
    {
        GENERIC = 1,
        DOMAIN_PASSWORD = 2,
        DOMAIN_CERTIFICATE = 3,
        DOMAIN_VISIBLE_PASSWORD = 4,
        GENERIC_CERTIFICATE = 5,
        DOMAIN_EXTENDED = 6,
        MAXIMUM = 7,      // Maximum supported cred type
        MAXIMUM_EX = (MAXIMUM + 1000),  // Allow new applications to run on old OSes
    }

public class CriticalCredentialHandle : Microsoft.Win32.SafeHandles.CriticalHandleZeroOrMinusOneIsInvalid
{
    public CriticalCredentialHandle(IntPtr preexistingHandle)
    {
        SetHandle(preexistingHandle);
    }

    public Credential GetCredential()
    {
        if (!IsInvalid)
        {
            NativeCredential ncred = (NativeCredential)Marshal.PtrToStructure(handle,
                  typeof(NativeCredential));
            Credential cred = new Credential();
            cred.CredentialBlobSize = ncred.CredentialBlobSize;
            cred.CredentialBlob = Marshal.PtrToStringUni(ncred.CredentialBlob,
                  (int)ncred.CredentialBlobSize / 2);
            cred.UserName = Marshal.PtrToStringUni(ncred.UserName);
            cred.TargetName = Marshal.PtrToStringUni(ncred.TargetName);
            cred.TargetAlias = Marshal.PtrToStringUni(ncred.TargetAlias);
            cred.Type = ncred.Type;
            cred.Flags = ncred.Flags;
            cred.Persist = ncred.Persist;
            return cred;
        }
        else
        {
            throw new InvalidOperationException("Invalid CriticalHandle!");
        }
    }

    override protected bool ReleaseHandle()
    {
        if (!IsInvalid)
        {
            CredFree(handle);
            SetHandleAsInvalid();
            return true;
        }
        return false;
    }
}

[DllImport("Advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool CredRead(string target, CRED_TYPE type, int reservedFlag, out IntPtr CredentialPtr);

[DllImport("Advapi32.dll", EntryPoint = "CredFree", SetLastError = true)]
public static extern bool CredFree([In] IntPtr cred);


"@
        try
        {
            Add-Type -MemberDefinition $sig -Namespace "ADVAPI32" -Name 'Util' -ErrorAction Stop
        } catch {
            Write-Error "$($MyInvocation.MyCommand.Name): Could not load custom type. $($_.Exception.Message)"
        }
    }

    End
    {
        $nCredPtr= New-Object IntPtr

        $success = [ADVAPI32.Util]::CredRead($TargetName,1,0,[ref] $nCredPtr)

        if ($success) {
            $critCred = New-Object ADVAPI32.Util+CriticalCredentialHandle $nCredPtr
            $cred = $critCred.GetCredential()
            $username = $cred.UserName

            # $securePassword = $cred.CredentialBlob | ConvertTo-SecureString -AsPlainText -Force
            $securePassword = New-Object Security.SecureString
            $cred.CredentialBlob.ToCharArray() | ForEach-Object { $securePassword.AppendChar($_) }
            $cred = $null
            Write-Output (New-Object System.Management.Automation.PSCredential $username, $securePassword)
        } else {
            throw "$($MyInvocation.MyCommand.Name): No credentials found in Windows Credential Manager for TargetName: $($TargetName)"
        }
    }
}
