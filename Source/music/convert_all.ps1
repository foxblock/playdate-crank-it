[CmdletBinding()]
param (
    [string]$targetFolder
)

$convertExe = "D:\Programme\adpcm-xq-win\64bit\adpcm-xq.exe"

if (-not $PSBoundParameters.ContainsKey('targetFolder')) {
    $targetFolder = Get-Location
}

Get-ChildItem $targetFolder -Filter *.wav | 
Foreach-Object {
    echo "Converting $($_.FullName)..."

    $oldFile = [IO.Path]::Combine($targetFolder, "old", $($_.Name))
    if (!(Test-Path $oldFile)) {
        New-Item -Path (Join-Path $targetFolder "old") -ItemType Directory -Force | Out-Null
    }
    Move-Item -Path $_.FullName -Destination $oldFile

    $cmd = "`"$convertExe`" -b8 -q `"$oldFile`" `"$($_.FullName)`""
    Invoke-Expression "& $cmd"
}