#GLOBAL DEFAULTS https://www.splunk.com/en_us/download/universal-forwarder.html
[CmdletBinding()]
param (
        [parameter(Mandatory=$true, HelpMessage='Enter absolute path to Splunk UF installer, ex: C:\users\user\downloads\splunkforwarder.msi')]
        [string]$SplunkForwarder,
        [parameter(Mandatory=$true, HelpMessage='Enter deployment server with port, ex: 10.1.1.10:8089')]
        [string]$DeploymentServer,
        [parameter(HelpMessage='Enter output location for install script (default is current user desktop')]
        [string]$InstallScript = ("c:\users\" + "$env:USERNAME" + "\desktop\installer.ps1")
)

function Convert-BinaryToString {
    [CmdletBinding()]
    param (
        [string] $FilePath
    )
    
    try {
        $ByteArray = [System.IO.File]::ReadAllBytes($FilePath);
    }
    catch {
        throw "Failed to read file. Please ensure that you have permission to the file, and that the file path is correct.";
    }
    
    if ($ByteArray) {
        $Base64String = [System.Convert]::ToBase64String($ByteArray);
    }
    else {
        throw "$ByteArray is $null.";
    }
    
    Write-Output -InputObject $Base64String;
}

#Embed binary into script generation
$Binary = Convert-BinaryToString -FilePath $SplunkForwarder

#Ask whether or not this will be placed in a virtual master image used for cloning
$YesOrNo = Read-Host -Prompt 'Create the installer for cloned virtual master image? Y/N'
If ("y", "Y" -contains $YesOrNo)
    {
        $LaunchSplunk = '0'
        $ServiceStartType = 'auto'
        $ClonePrep = '1'
    }
else 
    {
        $LaunchSplunk = '1'
        $ServiceStartType = 'auto'
        $ClonePrep = '0'
    }

#Generate installer script
$Installer = "function Convert-StringToBinary {
    [CmdletBinding()]
    param (
    [string] `$InputString`,
    [string] `$FilePath`
    )
    
    try 
    {
    if (`$InputString`.Length -ge 1) {
    `$ByteArray` = [System.Convert]::FromBase64String(`$InputString`);
    [System.IO.File]::WriteAllBytes(`$FilePath`, `$ByteArray`);
    }
    }
    catch {
    throw ('Failed to create file from Base64 string: {0}' -f `$FilePath`);
    }
    
    Write-Output -InputObject (Get-Item -Path `$FilePath`);
}

function Cleanup {
    Remove-Item -Path 'c:\temp\splunktemp\splunkforwarder.msi' -Force -Confirm:`$false` -ErrorAction SilentlyContinue
}

`$MSIArgs` = @(
            '/i'
            'c:\temp\splunktemp\splunkforwarder.msi'
            'AGREETOLICENSE=Yes'
            'SPLUNKUSERNAME=`"admin`"'
            'GENRANDOMPASSWORD=1'
            'DEPLOYMENT_SERVER=`"$DeploymentServer`"'
            'LAUNCHSPLUNK=`"$LaunchSplunk`"'
            'SERVICESTARTTYPE=`"$ServiceStartType`"'
            'CLONEPREP=`"$ClonePrep`"'
            '/qn'
            '/l*V c:\temp\splunktemp\install_log.log'
        )

#Disk space check
`$disk` = Get-PSDrive C | select Free

#Full uninstall/reinstall routine begins here
if (`$disk`.Free -gt 1073741824)
    {
        if ((Test-Path 'c:\temp\splunktemp') -ne `$true`)
        {
            New-Item -Path 'c:\temp\' -Name 'splunktemp' -ItemType 'directory' | Out-Null
        }

        `$TargetFile` = Convert-StringToBinary -InputString $Binary -FilePath c:\temp\splunktemp\splunkforwarder.msi

        try
            {    
                `$proc` = Start-Process -FilePath msiexec.exe -ArgumentList `$MSIArgs` -Wait -PassThru
                `$message` = `$proc`.ExitCode.ToString()

                if (`$message` -eq '0')
                    {
                        Write-Host (`$env`:COMPUTERNAME + ' success. Check c:\temp\splunktemp\install_log.log to confirm!')
                    }
                else
                    {
                        Write-Error (`$env`:COMPUTERNAME + ' failure. MSI error code ' + `$message`)
                        Write-Host 'Check c:\temp\splunktemp\install_log.log!'
                    }
        }
        catch
            {
                Write-Host (`$env`:COMPUTERNAME + ' installer failed to launch. Check c:\temp\splunktemp\install_log.log!')
        }
    }
    else
    {
         Write-Host 'Disk has less than 1GB of free space, cancelling install.'
    }
    
Cleanup"

#Output installer script
$Installer | Out-File -FilePath $InstallScript -Force

Write-Host "Installer script has been generated here: $InstallScript"
