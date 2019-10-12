[CmdletBinding()]
param (
    [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [string] $FilePath
)

function Compress-ByteArray {
	[CmdletBinding()]
    Param (
	[Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [byte[]] $byteArray
    )

	Process {
        [System.IO.MemoryStream] $inMemDataStream = New-Object System.IO.MemoryStream
        $gzipInstance = New-Object System.IO.Compression.GzipStream $inMemDataStream, ([IO.Compression.CompressionMode]::Compress)
        Write-Verbose -Message "Compressing..."
        $gzipInstance.Write( $byteArray, 0, $byteArray.Length )
        $gzipInstance.Close()
        $inMemDataStream.Close()
        [byte[]] $result = $inMemDataStream.ToArray()
        return Write-Output -NoEnumerate $result
    }
}

try {
    Write-Verbose -Message "Read file $FilePath into bytearray"
    $fileAsByteArray = [System.IO.File]::ReadAllBytes($FilePath);
}
catch {
    Write-Error "Ran into an issue: $($PSItem.ToString())"
}

if ($fileAsByteArray) {
    Write-Verbose -Message "Compress ByteArray of $($fileAsByteArray.Length) bytes"
    $fileAsCompressedByteArray = Compress-ByteArray($fileAsByteArray);
    
    Write-Verbose -Message "Compressed size of byte array `
        $($fileAsCompressedByteArray.Length) which is `
        $([math]::Round($($fileAsCompressedByteArray.Length/$fileAsByteArray.Length),3)*100)% `
        of the original size"

    Write-Verbose -Message "Converting byteArray to Base64String"
    $Base64String = [System.Convert]::ToBase64String($fileAsCompressedByteArray);
}
else {
    Write-Error "File is empty."
}
Write-Information -Message "Here comes the compressed file as a string!"
return Write-Output -NoEnumerate $Base64String;
