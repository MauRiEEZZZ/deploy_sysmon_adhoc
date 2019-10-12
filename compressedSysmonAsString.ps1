function DownloadSysmon {
    [cmdletbinding()]
    Param()
    $Result  = $(Test-Path (Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath sysmon.exe));
    if(-not $Result) {
        try {
            # https://msdn.microsoft.com/en-us/library/system.io.path.gettempfilename%28v=vs.110%29.aspx
            $tmpfile = [System.IO.Path]::GetTempFileName()
            $null = Invoke-WebRequest -SslProtocol Tls12 -Uri 'https://live.sysinternals.com/Sysmon.exe' `
                              -OutFile $tmpfile -ErrorAction Stop
            Write-Verbose -Message 'Sucessfully downloaded Sysmon.exe'
            Unblock-File -Path $tmpfile -ErrorAction Stop
            $exefile = Join-Path -Path (Split-Path -Path $tmpfile -Parent) -ChildPath 'a.exe'
            if (Test-Path $exefile) {
                Remove-Item -Path $exefile -Force -ErrorAction Stop
            }
            $tmpfile | Rename-Item -NewName 'a.exe' -Force -ErrorAction Stop

        } catch {
            Write-Verbose -Message "Something went wrong $($_.Exception.Message)"
        }
    }
}
function Expand-ByteArray {

	[CmdletBinding()]
    Param (
		[Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [byte[]] $byteArray
    )

	Process {
        [System.IO.MemoryStream] $inMemDataStream = New-Object System.IO.MemoryStream( , $byteArray )

	    $decompressedDataStream = New-Object System.IO.MemoryStream
        $gzipInstance = New-Object System.IO.Compression.gzipInstance $inMemDataStream, ([IO.Compression.CompressionMode]::Decompress)
	    Write-Verbose "Write-Verbose -Message "Decompressing byte array""
	    $gzipInstance.CopyTo( $decompressedDataStream )
        $gzipInstance.Close()
		$inMemDataStream.Close()
		[byte[]] $result = $decompressedDataStream.ToArray()
        return Write-Output -NoEnumerate $result
    }
}
function CreateSysmon {
    [cmdletbinding()]
    Param()
    $Result  = $(Test-Path (Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath sysmon.exe));
    if(-not $Result) {
        try {
            # https://msdn.microsoft.com/en-us/library/system.io.path.gettempfilename%28v=vs.110%29.aspx
            $tmpfile = [System.IO.Path]::GetTempFileName()
            $CompressedByteArray = [System.Convert]::FromBase64String($sysmonAsString);
            $ByteArray = Expand-ByteArray($CompressedByteArray);
            [System.IO.File]::WriteAllBytes($tmpfile, $ByteArray);
            Write-Verbose -Message 'Sucessfully created Sysmon.exe'
            #Unblock-File -Path $tmpfile -ErrorAction Stop
            $exefile = Join-Path -Path (Split-Path -Path $tmpfile -Parent) -ChildPath 'a.exe'
            if (Test-Path $exefile) {
                Remove-Item -Path $exefile -Force -ErrorAction Stop
            }
            $tmpfile | Rename-Item -NewName 'a.exe' -Force -ErrorAction Stop

        } catch {
            Write-Verbose -Message ‘Failed to create file from Base64 string: {0}’ -f $FilePath
        }
    }
    else {
        Write-Verbose false
    }
}
function TestSysmonFile {
    [cmdletbinding()]
    Param()
    $s = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath a.exe -ErrorAction SilentlyContinue
    if (-not(Test-Path -Path $s -PathType Leaf)) {
        Write-Verbose -Message "Cannot find sysmon.exe in temp"
        return $false
    }
    if(
        (Get-FileHash -Path $s -Algorithm SHA256).Hash -eq '8C50CE44732912726E5AB0958E4199DEEE77F904CD746369F37B91E67A9826C6' -and
        (Get-AuthenticodeSignature -FilePath $s).Status.value__ -eq 0 # Valid
    
    ) {
        Write-Verbose -Message 'Successfully found a valid signed sysmon.exe sysmon'
        return $true
    } else {
        Write-Verbose -Message 'A valid signed sysmon.exe was not found'
        return $false
    }
}

function InstallSysmon {
    [cmdletbinding()]
    Param()
    $Result  = $(if (@(Get-Service -Name sysmon,sysmondrv -ErrorAction SilentlyContinue).Count -eq 2) { $true } else { $false });
    if (-not $Result) {
        $sysmonbin = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath a.exe
        $s = Copy-Item -Path $sysmonbin -Destination "$($env:systemroot)\system32\sysmon.exe" -PassThru -Force
        try {
            $null = Start-Process -FilePath $s -ArgumentList @('-i','-accepteula') -PassThru -NoNewWindow -ErrorAction Stop | Wait-Process
            Write-Verbose -Message 'Successfully installed sysmon'
        } catch {
            $errorReturn = $_
            $errorResult = ($errorReturn | ConvertFrom-Json ).error
            Write-Verbose $_
            Write-Error "Unable to start Sysmon on $(env:Computername) with message: $($errorResult.message)" -ErrorAction Stop

        }
    }
}

function TestSysmonLog {
    if(
        Get-WinEvent -ListLog * | Where-Object LogName -eq 'Microsoft-Windows-Sysmon/Operational'
    ) {
        Write-Verbose -Message "Sysmon is installed"
        return $true
    } else {
        Write-Verbose -Message "Sysmon isn't installed"
        return $false
    }
}

CreateSysmon -Verbose
if (TestSysmonFile -Verbose) {
    InstallSysmon -Verbose
}
if (TestSysmonLog -Verbose) {
    Write-Output "Sysmon log exists"
}