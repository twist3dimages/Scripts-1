'==========================================================================
'
' VBScript Source File -- Created with SAPIEN Technologies PrimalScript 2011
'
' NAME: 
'
' AUTHOR: BrianG , 
' DATE  : 11/27/2013
'
' COMMENT: 
'
'==========================================================================
myProcess = "notepad.exe"
WScript.Echo "Checking for: " & myProcess

Do Until blnRunning = "False"
	Set objWMIService = GetObject("winmgmts:\\.\root\CIMV2")
	Set colItems = objWMIService.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" & _
		myProcess & "'", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
	WScript.Sleep 100 'Wait for 100 MilliSeconds
	If colItems.Count = 0 Then 'If no more processes are running, exit Loop
		blnRunning = False
	End If
Loop