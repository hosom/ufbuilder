#GLOBAL DEFAULTS
$SplunkForwarder = 'C:\Users\user\Downloads\splunkforwarder-8.0.4-767223ac207f-x64-release.msi'
$DeploymentServerParam = '999.999.999.999:8089'
$InstallScript = 'C:\Users\user\Desktop\installer.ps1'

function Convert-BinaryToString {
    [CmdletBinding()]
    param (
        [string] $FilePath
    )
    
    try {
        $ByteArray = [System.IO.File]::ReadAllBytes($FilePath);
    }
    catch {
        throw “Failed to read file. Please ensure that you have permission to the file, and that the file path is correct.”;
    }
    
    if ($ByteArray) {
        $Base64String = [System.Convert]::ToBase64String($ByteArray);
    }
    else {
        throw ‘$ByteArray is $null.’;
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

Try
{
    `$TargetFile`= Convert-StringToBinary -InputString $Binary -FilePath C:\temp\splunkforwarder.msi

    `$MSIArgs` = @(
        '/i'
        'C:\temp\splunkforwarder.msi'
        'AGREETOLICENSE=Yes'
        'SPLUNKUSERNAME=`"admin`"'
        'GENRANDOMPASSWORD=1'
        'DEPLOYMENT_SERVER=`"$DeploymentServerParam`"'
        '/qn'
        '/l*V c:\temp\install_log.log'
    )

    #Disk space check
    `$disk` = Get-PSDrive C | select Free

    #Full uninstall/reinstall routine begins here
    If (`$disk`.Free -gt 1073741824)
        {
            try
            {
            
                Start-Process -FilePath msiexec.exe -ArgumentList `$MSIArgs` -Wait -ErrorAction SilentlyContinue
                
                sleep -Seconds 5

                Remove-Item -Path 'C:\temp\splunkforwarder.msi' -Force -Confirm:$false

                Write-Host (`$env`:COMPUTERNAME + ' success. Check c:\temp\install_log.log to confirm!')
            }
            Catch
            {
                Write-Host (`$env`:COMPUTERNAME + ' failure! Check c:\temp\install_log.log!')
            }
        }
    else
    {
        Write-Host 'Disk has less than 1GB of free space, cancelling install!'
    }
}
Catch
{
    Write-Host 'Unpacking binary failure!'
}"

#Output installer script
$Installer | Out-File -FilePath $InstallScript -Force