'==========================================================================
' NAME: SecuritasFirstRun.vbs
' AUTHOR: Brian Gonzalez, Panasonic
' DATE  : 02.26.2013
' PURPOSE: Post Image Script for H2Mk1 For Securitas
'==========================================================================
On Error Resume Next
'Setup Objects and Constants
Const cForReading = 1, cForWriting = 2, cForAppending = 8
sScriptVersion = "02.26.2013"
Set oFSO = CreateObject("Scripting.FileSystemObject")
Set oShell = WScript.CreateObject("WScript.Shell")
Set oNetwork = createobject("Wscript.Network")
Set oWMI = GetObject("winmgmts:")

'Setup Vars
sScriptFolPath = oFSO.GetParentFolderName(Wscript.ScriptFullName) 'No trailing backslash
sLogFilePath = sScriptFolPath & "\SecuritasFirstRun.log"

'Get Short Names for easy use in Cmd.exe
sScriptFolPath = fGetShortName( sScriptFolPath )
sGobiResFolPath = fGetShortName( sScriptFolPath & "\GlobalCSA" )
sWSNameFilePath = sScriptFolPath & "\wsname.exe"
sPOWFilePath = sScriptFolPath & "\SecuritasPowerConfig.POW"
sIEConfigFilePath = sScriptFolPath & "\IE9-Setup-Full.msi"
sTSFolPath = fGetShortName( sScriptFolPath & "\DualTouchDriver_v7.0.3-7_H2A_H2B_W732_ss9602" )
sJavaFilePath = fGetShortName( sScriptFolPath & "\jre-7u17-windows-i586.exe" )
sJavaRegFilePath = sScriptFolPath & "\JaveUpdateOff.reg"
sFullScreenRegFilePath = sScriptFolPath & "\JaveUpdateOff.reg"

'PNPID Strings	
sGOBI2KFPNP = "VID_04DA&PID_250F" 'GOBI 2000 PNP ID
sGOBI2KEPNP = "VID_04DA&PID_250E" 'GOBI 2000 PNP ID

'Main Execution section of script
'==========================================================================
Set oLogFile = oFSO.OpenTextFile(sLogFilePath, cForWriting, True)
fLogHelper "SecuritasFirstRun script (v" & sScriptVersion & ") has begun on " & Date, ""

'Change Compname to "SEC-" and the system's serial number...
If oFSO.FileExists(sWSNameFilePath) Then
	sWSNameFilePath = fGetShortName(sWSNameFilePath)
	fLogHelper "Renaming Computer using wsname", "begin"
	For Each oBios In oWMI.InstancesOf("Win32_BIOS")
		sNewName = oBios.SerialNumber
	Next
	sNewName = "SEC-" & Trim( Left(sNewName, 10) )
	fLogHelper "Executing " & sCmd & "...", ""
	sCmd = sWSNameFilePath & " /N:" & sNewName
	sRet = oShell.Run(sCmd, 0, True)
	fLogHelper "Renamed Computer using wsname to """ & sNewName & """ complete", sRet
Else
	fLogHelper "WSName.exe (" & sWSNameFilePath & ") file not found..", ""
End If

'Reinstall the Dual Touchscreen driver
If oFSO.FolderExists(sTSFolPath) Then
	fLogHelper "Reinstalling Dual Touchscreen driver.", "begin"
	oShell.CurrentDirectory = sTSFolPath
	sCmd = "cmd.exe /c pinstall.bat"
	sRet = oShell.Run(sCmd, 0, True)
	fLogHelper "Dual Touchscreen driver install complete", sRet
Else
	fLogHelper "Dual Touchscreen driver folder (" & sTSFolPath & ") not found.", ""
End If

'Update Java to latest release
If oFSO.FileExists(sJavaFilePath) Then
	fLogHelper "Installing latest Java Client.", "begin"
	sCmd = sJavaFilePath & " /s /L C:\SOFTWARE\JavaInstall.log"
	sRet = oShell.Run(sCmd, 0, True)
	fLogHelper "Installation of Java is complete.", sRet

	fLogHelper "Setting Java to not Auto-Update.", "begin"
	sCmd = "cmd.exe /c reg import " & sJavaRegFilePath
	sRet = oShell.Run(sCmd, 0, True)
	fLogHelper "Setting Java to not Auto-Update is complete.", "begin"
Else
	fLogHelper "Latest Java Client(" & sJavaFilePath & ") not found.", ""
End If

'Disable Full Screen mode in IE
If oFSO.FileExists(sFullScreenRegFilePath) Then
	fLogHelper "Disabling FullScreen mode in IE9.", "begin"
	sCmd = "cmd.exe /c reg load HKLM\import C:\Users\Default\NTUSER.DAT"
	sRet = oShell.Run(sCmd, 0, True)
	sCmd = "cmd.exe /c reg import " & sFullScreenRegFilePath
	sRet = oShell.Run(sCmd, 0, True)
	sCmd = "cmd.exe /c reg unload HKLM\import"
	sRet = oShell.Run(sCmd, 0, True)
	fLogHelper "Disabling FullScreen mode in IE9 is complete.", "begin"
Else
	fLogHelper "Reg Key for disabling full screen mode(" & sFullScreenRegFilePath & ") not found.", ""
End If

'Inject Securitas IE configuration settings
If oFSO.FileExists(sIEConfigFilePath) Then
	sIEConfigFilePath = fGetShortName(sIEConfigFilePath)
	sCmd = "msiexec.exe /i " & sIEConfigFilePath & " /passive /log C:\SOFTWARE\IE9Config.log"
	fLogHelper "Executing " & sCmd & "...", ""
	sReturn = oShell.Run(sCmd, 0, True)
	If sReturn Then
		fLogHelper "Executing " & sCmd & " failed.", "begin"
	End If
	fLogHelper "Completed executing " & sCmd & "...", sReturn
Else
	fLogHelper "IE Config file (" & sIEConfigFilePath & ") not found.", ""
End If

'Delay script to let IE Configuration complete
Wscript.Sleep 15000

'Configure power plan
If oFSO.FileExists(sPOWFilePath) Then
	sPOWFilePath = fGetShortName( sPOWFilePath )
	sCmd = "cmd /c powercfg -import " & sPOWFilePath & " a83ffe77-647e-45df-899e-cd3f4e2835a1"
	fLogHelper "Executing " & sCmd & "...", ""
	sReturn = oShell.Run(sCmd, 0, True)
	If sReturn Then
		fLogHelper "Executing " & sCmd & " failed.", "begin"
	End If
	fLogHelper "Completed executing " & sCmd & "...", sReturn

	sCmd = "cmd /c powercfg -setactive a83ffe77-647e-45df-899e-cd3f4e2835a1"
	fLogHelper "Executing " & sCmd & "...", ""
	sReturn = oShell.Run(sCmd, 0, True)
	If sReturn Then
		fLogHelper "Executing " & sCmd & " failed.", "begin"
	End If
	fLogHelper "Completed executing " & sCmd & "...", sReturn
Else
	fLogHelper "Securitas PowerCfg (" & sPOWFilePath & ") not found.", ""
End If

'Disabling the Windows update service
oShell.Run "sc stop wuauserv"
fLogHelper "Stopping the windows Update service.", "begin"
oShell.Run "sc config wuauserv start= disabled"
fLogHelper "Disabling windows Update service.", err.Number

'Disabling Adobe Reader update
oShell.Run "sc stop AdobeARMservice"
fLogHelper "Stopping the Adobe Reader Update service.", "begin"
oShell.Run "sc config AdobeARMservice start= disabled"
fLogHelper "Disabling Adobe Reader Update service.", err.Number

'Detect and install appropiate WWAN Drivers
If fPNPMatch(sGOBI2KFPNP) Or fPNPMatch(sGOBI2KEPNP) Then
	fLogHelper "Gobi 2000 modem found setting up", "begin"
	If oFSO.FolderExists(sGobiResFolPath) Then
		If Not oFSO.FolderExists("C:\Program Files\Qualcomm\DriverPackage") Then
			sCmd = sGobiResFolPath & "\Gobi2kPackage\setup.exe -s -f2""c:\windows\temp\gobi2000.log"""
			fLogHelper "Executing: " & sCmd, "begin"
			sReturn = oShell.Run(sCmd, 0, True)
			If sReturn Then
				fLogHelper "Installing base gobi2000 components failed is complete, see c:\windows\temp\gobi2000.log for more info.", sReturn
			End If
			fLogHelper "gobi2000 Base components install is complete", sReturn
		Else
			fLogHelper "gobi2000 Base components already installed.", ""
		End If

		'Ensure Verizon firmware is applied
		sCmd = sGobiResFolPath & "\CSAPack\SetFirm2.exe -switch:vzw"
		fLogHelper "Executing: " & sCmd, "begin"
		sReturn = oShell.Run(sCmd, 0, True)
		If sReturn Then
			fLogHelper "Apply Verizon firmware completed with errors: ", sReturn
		End If
		fLogHelper "Apply Verizon firmware completed successfully.", sReturn
	Else
		fLogHelper "CSA (" & sGobiResFolPath & ") folder not found.", ""
	End If
End If

'Turn off Admin Auto Logon
oShell.RegWrite "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AutoAdminLogon", "0"
fLogHelper "Turned off Auto Admin Logon.", err.Number

'Delete shortcut in startup, if present
sShortcutPath = "C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\FirstRun - Shortcut.lnk"
If oFSO.FileExists(sShortcutPath) Then
	oFSO.DeleteFile sShortcutPath, True
	fLogHelper "Deleting shortcut to call script.", err.Number
End If
fLogHelper "Deleting shortcut routine complete.", ""

'Set timeout for BCDBoot to 0
oShell.Run "cmd /c bcdedit /timeout 0"

'Rebooting machine with prompt
fLogHelper "Rebooting machine..", "begin"
oShell.PopUp "Rebooting machine to complete configuration...", 15, "Configuration Complete", 64
oShell.Run "cmd /c c:\windows\system32\shutdown.exe /r /t 300 /f"

'Functions and Subs Section
'==========================================================================
Function fPNPMatch(sPNPDeviceID)
	Set oWMIService = GetObject("winmgmts:\\.\root\CIMV2")
	Set oItems = oWMIService.ExecQuery("SELECT * FROM Win32_PnPEntity WHERE PNPDeviceID LIKE '%" & sPNPDeviceID & "%'")
	fPNPMatch = oItems.Count
End Function

Sub fLogHelper(stepName, sRet)
	If Not IsObject(oLogFile) Then
		Set oLogFile = oFSO.OpenTextFile(sLogFilePath, cForAppending, True)
	End If

	If sRet = "" Then
		oLogFile.WriteLine(Time & ": General Update ( """ & stepName & """)")
	ElseIf sRet = "begin" Then
		oLogFile.WriteLine(Time & ": """ & stepName & """ begun.")
	Else
		oLogFile.WriteLine(Time & ": """ & stepName & """ ran and returned: " & sRet)
	End If
End Sub

Function fGetShortName(sPath)
	If oFSO.FolderExists(sPath) Then
		Set oTempFolder = oFSO.GetFolder(sPath)
		fGetShortName = oTempFolder.ShortPath
	End If
	If oFSO.FileExists(sPath) Then
		Set oTempFile = oFSO.GetFolder(sPath)
		fGetShortName = oTempFile.ShortPath
	End If
End Function
