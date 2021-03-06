<#
ChangeLog:
	- June 5, 2013 : Added -Alignment Parameter to "New-Partition" PS command (Un-Mountable XP Boot Volume Issue)
	- June 6, 2013 : Replaced "/force" with "/mbr" in bootsect.exe commnad.
    - Sept 12, 2013 : Added Recovery Partition functionality.
    - Sept 18, 2013 : Added password prompting and hide recovery partition.
#>

$sRecoveryPassword = $null

Function fMain {
trap {"Error found: $_" | Out-File "x:\SearchAndApply.log"}

    #Clear content in command window
	Clear-Host
        
    #Maximize Command Window
    <#
    #Doesn't Work...........
    $sig = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    Add-Type -MemberDefinition $sig -name NativeMethods -namespace Win32
    $hwnd = @(Get-Process "*Windows Powershell*")[0].MainWindowHandle
    [Win32.NativeMethods]::ShowWindowAsync($hwnd, 3)
    #>
    
    Write-Output "Beginning to search for .WIM file..."
    #Finds the LATEST >1G .WIM File in the root of Logical Disks
	$oWimFiles = Get-WmiObject -Query "SELECT * From Win32_LogicalDisk WHERE NOT DeviceID LIKE 'A' AND Size > 0 AND NOT DriveType LIKE '4'" | `
        #Commented out on 9/6/2013 DriveType 5 is for CDr/DVDr Types.
		#Where-Object { $_.DriveType -ne "5" } | `
		foreach { Get-ChildItem -Force -Path @($_.DeviceID + "\") } | `
		Where-Object { ($_.FullName -Like "*.wim") -and ($_.Length -ge 1000000000) } | `
		Sort-Object -Descending CreationTime
	If ($oWimFiles -eq $null) {Write-Output "No .WIM files found..."; Exit}
    
    #Grab Drive Object of where .WIM was located.
    $oWimDrive = Get-WmiObject -Query ("SELECT * From Win32_LogicalDisk WHERE DeviceID LIKE '%" + $oWimFiles[0].PSDrive + "%'")

    #If .WIM is in RECOVERY partition, then only a format on the OSDISK partition is required.
    If ($oWimDrive.VolumeName -eq "RECOVERY") {
        
        $sRecDrive = $oWimDrive.DeviceID
        Write-Output "Latest WIM was found IN Recovery Partition($sRecDrive)..."
	    Write-Output @("Found the following image: " + $oWimFiles[0].FullName)

        $oDrives = Get-WmiObject -Query "SELECT * FROM Win32_LogicalDisk WHERE DriveType LIKE 3" | `
		    Sort-Object -Descending Size

        fCreateAnswerFiles
        If (!(Test-Path("$env:temp\configHD2.txt"))) {
        Write-Output "Could not access Temp Drive..."; Exit}
        Write-Output "Formating OSDIsk Partition..."
        Start-Process "x:\windows\system32\cmd.exe" @('/C diskpart.exe /s configHD2.txt"') -Wait -WorkingDirectory $env:temp -WindowStyle Minimized | Out-Null

    }else{

        #.WIM was NOT located in RECOVERY, so re-building all partitions.
        $sRecDrive = "R:"
        Write-Output "Latest WIM was found OUT of Recovery Partion."
	    Write-Output @("Found the following image: " + $oWimFiles[0].FullName)

        #Checks if "Local Disk" found is over 100GB.
	    $Disk = Get-Disk -Number 0 | Where-Object { $_.Size -gt 100000000000 }
	    If ($Disk -eq $null) {Write-Output "100GB Local Disk is not found, exiting script..."; Exit}

        #Call Function to create Diskpart answer files.
        fCreateAnswerFiles
        If ((!(Test-Path("$env:temp\configHD.txt"))) -and (!(Test-Path("$env:temp\configHD2.txt")))) {
        Write-Output "Could not access Temp Drive..."; Exit}
        Write-Output "Re-Partitioning Disk..."

        #Re-partition the disk
        Start-Process "x:\windows\system32\cmd.exe" @('/C diskpart.exe /s configHD.txt"') -Wait -WorkingDirectory $env:temp -WindowStyle Minimized | Out-Null

        Write-Output "Prep Recovery Partition before applying WIM to OSDISK..."
        #Copy-Item -Path ($oWimFiles[0].DirectoryName + "*") -Destination $sRecDrive -Recurse -Confirm:$false -Force
	    Start-Process "x:\windows\system32\cmd.exe" @('/C robocopy.exe "' + $oWimFiles[0].DirectoryName.SubString(0,2) + `
            '" "' + $sRecDrive + '" /MIR /NJS /NJH /NP') -Wait -NoNewWindow | Out-Null
    }    
    #Provide Status on what .WIM file will be applied.
    Write-Output @('Begin applying image to OS partition...')
	Start-Process "x:\windows\system32\cmd.exe" @('/C "imagex /apply "' + `
		$sRecDrive + '\' + $oWimFiles[0].Name + '" 1 C:"') -Wait -NoNewWindow | Out-Null
	Write-Output "Completed with applying image."

    #Delete old BCD file
    attrib C:\Boot\BcD -H -S
    Remove-Item  C:\Boot\BcD -Force

    #Build a new one using bcd boot
    Start-Process "x:\windows\system32\cmd.exe" @('/C bcdboot c:\windows /s c:') -Wait -WindowStyle Minimized | Out-Null

    #Add Recovery WinPE boot option to BCD using BCDEdit script
    fCreateBuildBCDFile
    If (!(Test-Path("$env:temp\configBCD.bat"))) {
    Write-Output "Could not access Temp Drive..."; Exit}
    Start-Process "x:\windows\system32\cmd.exe" @('/C call configBCD.bat ' + $sRecDrive) -Wait -WorkingDirectory $env:temp -WindowStyle Minimized | Out-Null

	Write-Output @("Boot sector and BCD is prepped.")
	Sleep -Seconds 5
	If (Test-Path("C:\Windows")) {
        [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic") | Out-Null
        [Microsoft.VisualBasic.Interaction]::MsgBox("Image was recovered. Click OK to Shut Down the System.",'OKOnly,Information', "Process Complete") | Out-Null
		Start-Process "x:\windows\system32\wpeutil.exe" @('"shutdown"')
	} else {
		Write-Output @("ImageX did not apply image successfully.... Shutting down in 5 seconds...")
		"ImageX did not apply image successfully." | Out-File "x:\SearchAndApplyError.log"
		Exit
	}
}


Function fCreateAnswerFiles {
'select disk 0
clean
create partition primary size=25000
select partition 1
format fs=ntfs label="RECOVERY" quick
assign letter = R
create partition primary
select partition 2
format fs=ntfs label="OSDISK" quick
assign letter = C
active
exit' | Out-File "$env:temp\configHD.txt" -Encoding ascii

'select disk 0
select partition 2
format fs=ntfs label="OSDISK" quick
assign letter = C
exit' | Out-File "$env:temp\configHD2.txt" -Encoding ascii
}

Function fCreateBuildBCDFile {
'@echo off
setlocal

SET BCDEDIT=bcdedit.exe
SET BCDSTORE=C:\Boot\BCD
SET SDI_FILE=boot.sdi
SET WIM_File=boot.wim
SET RECDRV=%1

REM Replace 7 Bootmgr with 8 Bootmgr
attrib c:\bootmgr -H -S
del c:\bootmgr /F
copy %RECDRV%\bootmgr c:\bootmgr

REM Set Timeout value to 5
%BCDEDIT% /store %BCDSTORE% /timeout 5

echo.
echo Adding Ram Disk Options
echo ===========

for /f "Tokens=3" %%A in (''%BCDEDIT% /store %BCDSTORE% /create /device'') do set ramdisk=%%A 

%BCDEDIT% /store %BCDSTORE% /set %ramdisk% ramdisksdidevice partition=%RECDRV%
%BCDEDIT% /store %BCDSTORE% /set %ramdisk% ramdisksdipath \boot\%SDI_FILE% 
echo.

echo.
echo Adding Win PE
echo ===========
echo.

for /f "Tokens=3" %%A in (''%BCDEDIT% /store %BCDSTORE% /create /application osloader'') do set GUID=%%A

echo.
echo recovery guid=%GUID%
echo.

%BCDEDIT% /store %BCDSTORE% /set %GUID% systemroot \Windows
%BCDEDIT% /store %BCDSTORE% /set %GUID% detecthal Yes
%BCDEDIT% /store %BCDSTORE% /set %GUID% winpe Yes
%BCDEDIT% /store %BCDSTORE% /set %GUID% osdevice ramdisk=[%RECDRV%]\Sources\%WIM_File%,%ramdisk%
%BCDEDIT% /store %BCDSTORE% /set %GUID% device ramdisk=[%RECDRV%]\Sources\%WIM_File%,%ramdisk%
%BCDEDIT% /store %BCDSTORE% /set %GUID% description "Recovery"
%BCDEDIT% /store %BCDSTORE% /displayorder %guid% /addlast

echo.
echo.
endlocal' | Out-File "$env:temp\configBCD.bat" -Encoding ascii
}

#Prompt if they want to run Recovery
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic") | Out-Null
$Answer = [Microsoft.VisualBasic.Interaction]::MsgBox("Would you like to run the recovery routine?",'YesNo,Question', "Execute Recovery")
If ($Answer -ne "Yes") {Exit}

#Prompt for Password
If ($sRecoveryPassword -ne $null) {
    $PasswordMatch = $False
    Do  {
        $password = Read-Host -Prompt "Please enter the Recovery password" -AsSecureString
        $marshal = [System.Runtime.InteropServices.Marshal]
        $ptr = $marshal::SecureStringToBSTR($password)
        $password = $marshal::PtrToStringBSTR($ptr)
        If ($password -eq $sRecoveryPassword) {$PasswordMatch = $true}
    } While ($PasswordMatch -eq $false)
}

#Begin Recovery Routine
fMain