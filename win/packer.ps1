#GLOBAL DEFAULTS
[CmdletBinding()]
param (
        [parameter(Mandatory=$true, HelpMessage='Enter absolute path to Splunk UF installer, ex: C:\users\user\downloads\splunkforwarder.msi')]
        [string]$SplunkForwarder,
        [parameter(Mandatory=$true, HelpMessage='Enter deployment server with port, ex: 10.1.1.10:8089')]
        [string]$DeploymentServer,
        [parameter(HelpMessage='Enter output location for install script (default is current user desktop')]
        [string]$InstallScript = ("c:\users\" + "$env:USERNAME" + "\desktop\installer.ps1")
)
#https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=windows&version=8.0.4&product=universalforwarder&filename=splunkforwarder-8.0.4-767223ac207f-x64-release.msi&wget=true
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

#Generate installer script
$Installer = "function Convert-StringToBinary {
    [CmdletBinding()]
    param (
    [string] `$InputString`,
    [string] `$FilePath`
    )
    
    try {
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
            New-Item -Path 'c:\temp\' -Name 'splunktemp' -ItemType 'directory'
        }

        `$TargetFile`= Convert-StringToBinary -InputString $Binary -FilePath c:\temp\splunktemp\splunkforwarder.msi

        try
            {    
                Start-Process -FilePath msiexec.exe -ArgumentList `$MSIArgs` -Wait

                Write-Host (`$env`:COMPUTERNAME + ' success. Check c:\temp\splunktemp\install_log.log to confirm!')
        }
        catch
            {
                Write-Host (`$env`:COMPUTERNAME + ' failure. Check c:\temp\splunktemp\install_log.log!')
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
