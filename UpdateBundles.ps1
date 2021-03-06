$StartingFolder = "D:\Egnyte\Content\Shared\One-Click Bundles"
$UpdatedBundleFolder = "D:\Egnyte\Content\Shared\One-Click Bundles\Tools\LatestBundleFiles"
$BuildBatFolderPath = "D:\Applications\7Zip_SFX_Creator"

Get-ChildItem $StartingFolder -Filter "install.exe" -Recurse | 
    foreach{
        $WorkingFolding = $_.DirectoryName
        $TargetExePath = Split-Path $WorkingFolding -Parent
        $SrcDirectory = (Get-ChildItem -Path $WorkingFolding | Where-Object {$_.Attributes -eq "Directory"}).FullName
        
        Write-Output @('Starting processing: ' + $WorkingFolding)
        Write-Output @('Target .exe directory: ' + $TargetExePath)
        Write-Output @('Zip file directory: ' + $SrcDirectory)
        
        If ($WorkingFolding -like "*-XP*") {Copy-Item "$UpdatedBundleFolder\XP\*.*" $SrcDirectory -Force}
        If ($WorkingFolding -like "*-7*") {Copy-Item "$UpdatedBundleFolder\7\*.*" $SrcDirectory -Force}
        If ($WorkingFolding -like "*-7X86*") {Copy-Item "$UpdatedBundleFolder\7X86\*.*" $SrcDirectory -Force}
        If ($WorkingFolding -like "*-7X64*") {Copy-Item "$UpdatedBundleFolder\7X64\*.*" $SrcDirectory -Force}
        Copy-Item "$UpdatedBundleFolder\*.*" $WorkingFolding -Force
        Start-Process -FilePath "C:\windows\system32\cmd.exe" -WindowStyle Minimized `
            -ArgumentList @('/C CALL BuildExe.bat "' + $_.DirectoryName + '"') -Wait `
            -WorkingDirectory $BuildBatFolderPath
        Get-ChildItem "$BuildBatFolderPath\*.exe" | Where-Object { $_.Length -gt 1000*1024 } | `
            % { Move-Item $_ $TargetExePath -Force }
        Write-Output @('Finished processing to: ' + $TargetExePath)
        Start-Sleep -Seconds 100
        }