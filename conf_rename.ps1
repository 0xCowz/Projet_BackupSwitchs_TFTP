$basePath = "D:\Backup-Switch"

Write-Host "surveillance demarree sur $basePath"

while ($true) {
    try {
        $files = Get-ChildItem -Path $basePath -Recurse -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -match '\.conf-\d+$' }

        foreach ($file in $files) {
            $newName = $file.FullName -replace '\.conf-\d+$', '.conf'

            if (-not (Test-Path $newName)) {
                Rename-Item -Path $file.FullName -NewName $newName -ErrorAction Stop
                Write-Host "rename ok : $($file.Name) -> $(Split-Path $newName -Leaf)"
            }
            else {
                Write-Host "fail rename, cible existe : $newName"
            }
        }
    }
    catch {
        Write-Host "fail global : $($_.Exception.Message)"
    }

    Start-Sleep -Seconds 30
}
