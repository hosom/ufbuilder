function Convert-StringToBinary {
    [CmdletBinding()]
    param (
    [string] $InputString,
    [string] $FilePath
    )
    
    try {
    if ($InputString.Length -ge 1) {
    $ByteArray = [System.Convert]::FromBase64String($InputString);
    [System.IO.File]::WriteAllBytes($FilePath, $ByteArray);
    }
    }
    catch {
    throw ('Failed to create file from Base64 string: {0}' -f $FilePath);
    }
    
    Write-Output -InputObject (Get-Item -Path $FilePath);
}

Try
{
    $TargetFile= Convert-StringToBinary -InputString 89MBOFBASE64YEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==

    $MSIArgs = @(
        '/i'
        'C:\temp\splunkforwarder.msi'
        'AGREETOLICENSE=Yes'
        'SPLUNKUSERNAME="admin"'
        'GENRANDOMPASSWORD=1'
        'DEPLOYMENT_SERVER="999.999.999.999:8089"'
        '/qn'
        '/l*V ./install_log.log'
    )

    #Disk space check
    $disk = Get-PSDrive C | select Free

    #Full uninstall/reinstall routine begins here
    If ($disk.Free -gt 1073741824)
        {
            try
            {
            
                Start-Process -FilePath msiexec.exe -ArgumentList $MSIArgs -Wait -ErrorAction SilentlyContinue
                
                sleep -Seconds 5

                Remove-Item -Path 'C:\temp\splunkforwarder.msi' -Force -Confirm:False

                Write-Host ($env:COMPUTERNAME + ' success. Check c:\temp\install_log.log to confirm!')
            }
            Catch
            {
                Write-Host ($env:COMPUTERNAME + ' failure! Check c:\temp\install_log.log!')
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
}