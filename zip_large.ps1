# ---- Settings ----
$SevenZip = "C:\Program Files\7-Zip\7z.exe"
$Password = "arkh91"
$MinSize  = 50MB      # files smaller than this are skipped
$MaxPart  = 4000MB    # no output file may exceed this size
$Margin   = 1MB       # headroom so zip overhead doesn't create a tiny extra part

# ------------------------------------------------------------
# Function: Zip-File
# Usage:    Zip-File -File $fileInfo
#           (e.g. Zip-File -File (Get-Item .\x.mkv))
# Effect:   - file <= 4000MB : creates <basename>.zip
#           - file  > 4000MB : creates equal parts
#                              <basename>.zip.001, .002, ...
#             (number of parts = smallest N so each part < 4000MB)
#           All output is password-protected.
#
#    powershell -ExecutionPolicy Bypass -File "C:\path\to\zip_large.ps1"
#
# ------------------------------------------------------------
function Zip-File {
    param([System.IO.FileInfo]$File)

    $zipPath = Join-Path $File.DirectoryName ($File.BaseName + ".zip")

    if ($File.Length -le $MaxPart) {
        Write-Host "Zipping $($File.Name) ..."
        & $SevenZip a -tzip "-p$Password" $zipPath $File.FullName
    }
    else {
        # Number of equal parts needed, then the size of each part
        $parts    = [math]::Ceiling($File.Length / ($MaxPart - $Margin))
        $partSize = [math]::Ceiling($File.Length / $parts) + $Margin

        Write-Host ("Zipping {0} into {1} parts of ~{2} MB ..." -f `
            $File.Name, $parts, [math]::Round($partSize / 1MB))
        & $SevenZip a -tzip "-p$Password" "-v${partSize}b" $zipPath $File.FullName
    }
}

# Loop over files in the current folder only
Get-ChildItem -File | Where-Object {
    $_.Length -ge $MinSize -and
    $_.Extension -ne ".zip" -and
    $_.Name -notmatch '\.zip\.\d+$' -and
    $_.Name -ne $MyInvocation.MyCommand.Name
} | ForEach-Object { Zip-File -File $_ }

Write-Host "Done."
