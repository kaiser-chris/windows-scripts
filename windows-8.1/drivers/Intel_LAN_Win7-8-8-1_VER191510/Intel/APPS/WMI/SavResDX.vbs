' Updated for Static IP in Adapters and Teams
Option Explicit
Dim colArgs, strSettingsFile, SValueSet, SessionObject, NetServiceObject
Dim strIfSetFile, strFileName, strSave, strChoices, strInput, bError, strNetSerObjPath
Dim strSettingName, strFname, index, bUserInput, bModified, NetServiceSet
Dim totalAdapters, totalTeams, existTotalAdapters, bNewTeam, ServiceObject, FinalTargetObj
Dim AdapterSets, AdapterObj, wbemServices, strComputer, bHasTeamOrVLAN, wbemServices1
Dim bMisMatch, bSelected, strSettingsIndex, strCapabilities, strAdapterName, strAdapterPCIDeviceID, strOrgDispName, strAdapterBDF
Dim arrPrivDesc(), arrTeamPrivDesc(), Adapters(), Captions(), Teams() ,AdapterPath(), AdapterPCIDeviceID()
Dim TeamsObjSet, TeamObj,Temp ,VLANObjSet, VLANObj, virtualAdapterSets, virtualAdapterObj
Dim bMFOEnabled, shell, IPFilePath, HyperVFilePath, WINSFilePath, bBdfRestore
const HKEY_LOCAL_MACHINE = &H80000002
const ET_Supported = "FALSE"
Dim strRemove, strRemoveAnsOnly
Dim OSVersion, OSProductType
Dim isPowerManagementSupported
Dim bNoAns
Dim Arg
Dim isTimeOutValueModified, oldTimeOutValue
bNoAns = false
isPowerManagementSupported = False

dim strOEMCustomizeableValue, strOS

const NCS_ADAPTER_CAP_VENDOR_INTEL = 47
const SETTINGS_INDEX = 5
const NCS_ADAPTER_CAP_BASIC_DMIX    = 73
const NCS_ADAPTER_CAP_EXTENDED_DMIX = 74

'Dim blTenGigFETeamError
'blTenGigFETeamError = False

'During DMiX-to-DMiX upgrade scenarios only, the PermanentAddress 
'will be stored in the config file instead of the PCIDeviceID.
'The is due to the fact that the initial release of DMiX 
'did not have support for the PCIDeviceID property.
Dim bIsUpgrade		
bIsUpgrade = False	'Initialize to FALSE.
Dim InParameterETObj,TempETObject,OutParameterETObj


Set shell = CreateObject("WScript.Shell")
'  	Set env = shell.Environment("USER")

IPFilePath = "StaticIP.txt"

HyperVFilePath = "HyperV.txt"

WINSFilePath = "WINS.txt"

' arrays used to store TeamedMemberAdapter Information
' poor workaround for Wscript 5.1 (Windows 2000) - classes are not supported
Dim TeamedMemberAdapterName(64, 10)
Dim TeamedMemberAdapterPCIDeviceID(64, 10)
Dim TeamedMemberAdapterPreferredPrimarySetting(64, 10)
Dim TeamedMemberAdapterBDF(64, 10)
' Dim TeamedMemberAdapterGroupComponentSetting(64, 10) ' not currently used 
Dim TeamedMemberAdapterPartComponentSetting(64, 10)

Const maxAdapterTeamVLANs = 64
Const maxAdapterTeam = 64

Const wbemFlagAmendedCreateOnly = &h20002  
Const wbemFlagAmendedUpdateOnly = &h20001

Const maxSettings = 1000
Const DefaultFileName = "WmiConf.txt"

Const SLA_TEAM_TYPE = "2"
Const GEC_TEAM_TYPE = "3"

Set colArgs = WScript.Arguments
strComputer = "."

CheckAdminRights()

GetOSVersion()

' Check submitted arguments, show Usage for no arguments, ? or help arguments
If (WScript.Arguments.Count = 0) Then 
	PrintUsage()
Else 
	If (WScript.Arguments(0) = "?" ) OR (LCase(WScript.Arguments(0)) = "help") Then
		PrintUsage()
	Else
		strSettingsFile = defaultFileName
		' Assign variables after determining what combination of options have been submitted
        For Each Arg in WScript.Arguments
            Select Case LCase(Arg)
            Case "save"
                strSave = "TRUE"
            Case "restore"
                strSave = "FALSE"
            Case "upsave"
                bIsUpgrade = True
				strSave = "TRUE"
            Case "uprestore"
                bIsUpgrade = True
				strSave = "FALSE"
            Case "removeansonly"
                strRemove = "TRUE"
		If WScript.Arguments.Count > 1 Then
			MsgBox "ans only"
		End If
            Case "remove"
                strRemove = "TRUE"
		If WScript.Arguments.Count > 1 Then
			MsgBox "remove all"
		End If

            Case "/bdf"
                bBdfRestore = TRUE
            Case Else
                strSettingsFile = Arg
            End Select
        Next
	
		'Execute Save, Restore, Install or Remove on what data user submitted, depending on the arguments set above			
		If (bIsUpgrade = True) AND (strSave = "TRUE") Then
			WScript.Echo "Executing Save during upgrade on local computer with " & strSettingsFile
			SaveSettings(strSettingsFile)
		ElseIf (bIsUpgrade = True) AND (strSave = "FALSE") Then
			WScript.Echo "Executing Restore during upgrade on local computer with " & strSettingsFile
			RestoreSettings(strSettingsFile)
		ElseIf strSave = "TRUE" Then		
			WScript.Echo "Executing Save on local computer with " & strSettingsFile
			SaveSettings(strSettingsFile)
		ElseIf strSave = "FALSE" Then
			WScript.Echo "Executing Restore on local computer with " & strSettingsFile
			RestoreSettings(strSettingsFile)
		Elseif strRemove  = "TRUE" Then
			WScript.Echo "Executing Remove on local computer"
			Remove()
		Else				
			WScript.Echo "Unrecognized keyword:  " & WScript.Arguments(0) & ".  Keyword must be 'save' or 'restore' or 'remove' only."
		End If
	End If
End If

Sub GetOSVersion()
	Dim objWMI, objItem, colItems

	Set objWMI = GetObject("winmgmts:\\.\root\cimv2")
	Set colItems = objWMI.ExecQuery("Select * from Win32_OperatingSystem",,48)

	For Each objItem in colItems
	  OSVersion = Left(objItem.Version,3)

	  ' Stop errors from causing the script to fail. 
	  ' ProductType is not in the Windows 2000 or NT4 WMI
	  On Error Resume Next
	    OSProductType = Left(objItem.ProductType,2)
	
	    ' If there was an error accessing this property, we know the OS is Windows 2000 or NT4
	    if err.number <> 0 then
		' Set OSProductType to an arbitrary value.  It is only checked if the OSVersion is 5.2
		OSProductType = -1
 	    end if

	  On Error Goto 0  ' Allow errors to halt the script again

	Next
		
End Sub

'=======================================================================================
'
' Sub:	CheckAdminRights()
'  
'=======================================================================================
Sub CheckAdminRights

	Dim oReg
	Set oReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")

	Const HKEY_LOCAL_MACHINE = &H80000002
	Const HKEY_CLASSES_ROOT  = &H80000000
	Const HKEY_CURRENT_USER  = &H80000001
	Const KEY_CREATE         = &H0020

	Dim bHasAccessRights: bHasAccessRights = False
	Dim bHasAccessRights2: bHasAccessRights2 = False
	Dim bHasAccessRights3: bHasAccessRights3 = False
	Dim bHasAccessRights4: bHasAccessRights4 = False

	oReg.CheckAccess HKEY_LOCAL_MACHINE, "SOFTWARE\" , KEY_CREATE, bHasAccessRights
	oReg.CheckAccess HKEY_LOCAL_MACHINE, "SYSTEM\" , KEY_CREATE, bHasAccessRights2
	oReg.CheckAccess HKEY_CURRENT_USER, "CONTROL PANEL\" , KEY_CREATE, bHasAccessRights3
	oReg.CheckAccess HKEY_CLASSES_ROOT, "CLSID\" , KEY_CREATE, bHasAccessRights4

	If ((bHasAccessRights = False) Or (bHasAccessRights2 = False) or (bHasAccessRights3 = False) or (bHasAccessRights4 = False)) Then
	  WScript.echo "Save/Restore Script requires Administrative Rights.  Please log in as an Administrator and try again.  In Windows* Vista, this script must be run as the built-in Administrator.  Other users with administrative rights do not have sufficient rights to execute this script.", 0, "Intel(R) Save/Restore Script"
	  WScript.Quit(0)
	End If

End Sub

'=======================================================================================
'
' Sub:		SaveOemCustomizeableSetting()
' Description:	Saves the current value of OEMCustomizeable in the NCS2 dmix key
'  
'=======================================================================================
function SaveOemCustomizeableSetting()
	dim regAccess
	dim strKeyPath, strValueName, dwValue
	dim retValue
	
	const KEY_QUERY_VALUE 	= &H0001
	const HKEY_LOCAL_MACHINE = &H80000002

	set regAccess = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")

	strKeyPath = "SOFTWARE\Intel\Network_Services\NCS2"
	strValueName = "OEMCustomizeable"
	regAccess.GetDWORDValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,dwValue

	retValue = "OEMCustomizeable=" & dwValue
	
	SaveOemCustomizeableSetting=retValue

end function

'=======================================================================================
'
' Sub:		RestoreOemCustomizeableSetting()
' Description:	Restores the saved value of OEMCustomizeable in the NCS2 dmix key
'  
'=======================================================================================
sub RestoreOemCustomizeableSetting(byVal setting)
	dim regAccess
	dim strKeyPath, strValueName, dwValue
	const HKEY_LOCAL_MACHINE = &H80000002

	if setting <> "" then 
		wscript.echo "Setting Oem Customizeable Value"
		set regAccess = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
		
		strKeyPath = "SOFTWARE\Intel\Network_Services\NCS2"
		strValueName = "OEMCustomizeable"
		
		regAccess.SetDWORDValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,setting
	end if
end sub

'=======================================================================================
'
' Sub:	PrintUsage()
'  
'=======================================================================================
Sub PrintUsage()
	WScript.Echo "Intel(R) SavResDx.vbs version 1.0 "
	WScript.Echo "Copyright (C) Intel, Inc. 2013. All rights reserved."
	WScript.Echo ""
	WScript.Echo "   Usage: SavResDX.vbs keywords default/settingsfile"
	WScript.Echo "   Keywords are required and are 'save' or 'restore' only."
	WScript.Echo "   Settings file can be the keyword 'default' or an explicit file name."
	WScript.Echo "   Settings filename must include the file path."
	WScript.Echo "   Default filename is WMIConf.txt, saved to the current directory."
	WScript.Echo "   Default filename is used if no settings filename is given or"
	WScript.Echo "   the keyword 'default' is used."  
End Sub

'=======================================================================================
'
' Sub:  SaveSettings(ByVal strFname)
'		Save Adapter's, team's and VLAN's info. and settings info. to a text file.
'		Save Adapter's compatiblity settings. 
'  
'=======================================================================================
Sub SaveSettings(byVal strFileName)	
	dim colNetDevicesPhysical,colNetDevicesLogical
	dim objNetDevicePhyObj,objFile,objNetDeviceLogObj
	dim wbemServices
	dim DeviceIndex

	'Create a configuration file
	If IsEmpty(CreateConfigFile(strFileName)) Then
		Exit sub
	Else
		Set objFile=CreateConfigFile(strFileName)
	End If
	objFile.WriteLine "*** NCS2 DMiX Save Data ***"
	objFile.WriteLine "*** Date " & Date & " Time " & Time() & "  ***"
	objFile.WriteLine "**********************************************"
	objFile.WriteLine ""	
	' Save the OEMCustomeizable Setting for ViiV
	objFile.WriteLine SaveOemCustomizeableSetting()
	objFile.WriteLine "OS=" & OSVersion
	
'	Set wbemServices = GetObject("winmgmts://./root/IntelNcs2")  
	Set wbemServices = GetObject("winmgmts:{impersonationLevel=impersonate}//./root/IntelNcs2")	
	wbemServices.Security_.Privileges.AddAsString "SeLoadDriverPrivilege", True
	
	'Get all instances from IANet_PhysicalEthernetAdapter for adapters
	
	Set colNetDevicesPhysical = wbemServices.InstancesOf("IANet_PhysicalEthernetAdapter") 
	'Save Adapters 
	DeviceIndex=1	
     dim bIsLADIntelDevice
     dim LastCapIndex
     For each objNetDevicePhyObj in colNetDevicesPhysical
          bIsLADIntelDevice = false
          
	
	'Checks if the device is an Intel Device
	IsIntelDevice objNetDevicePhyObj, bIsLADIntelDevice 
          
          'Save settings for only Intel adapters by checking for Non-Intel and disabled adapters 
          If (bIsLADIntelDevice AND (objNetDevicePhyObj.StatusInfo= 3)) then                    
               'Save Adapter specific info               
                    objFile.WriteBlankLines(1)                    
                    SaveAdapterInfo objFile, objNetDevicePhyObj, DeviceIndex                    
                    
                    SaveAdvancedSettings objFile, objNetDevicePhyObj, wbemServices
                    SaveVlanSettings objFile, objNetDevicePhyObj, wbemServices
                    DeviceIndex=DeviceIndex + 1
          End if
      Next
	
	objFile.WriteBlankLines(1)
	
	'Get all instances from IANet_LogicalEthernetAdapter for teams
	Set colNetDevicesLogical = wbemServices.InstancesOf("IANet_LogicalEthernetAdapter") 

	' SCR 50668 Fix:  Without ANS installed, the IANet_LogicalEthernetAdapter class
	' Is not exposed in the WMI, causing the for each loop below to fail.  Since 
	' isNull() and isEmpty() are not reflecting when IANet_LogicalEthernetAdapter
	' is not there, it was needed to be done like this.  
	
	' Turn on error handling (script does not halt on errors)
	on Error Resume Next
		For each objNetDeviceLogObj in colNetDevicesLogical

			' check if there was an error accessing the Logical Adapter collection
			' if not, get the ANS information
			if err.number = 0 then
				'Save Team specific info
				SaveTeamInfo objFile, objNetDeviceLogObj, DeviceIndex, wbemServices			
				SaveTeamAdvancedSettings objFile, objNetDeviceLogObj, wbemServices
				SaveVlanSettings objFile, objNetDeviceLogObj, wbemServices
				DeviceIndex=DeviceIndex + 1
				objFile.WriteBlankLines(1)	
			end if
		Next

	' Turn off error handling (script halts on errors again)
	on Error Goto 0
	
	objFile.WriteBlankLines(1)
	
	objFile.close
	Wscript.Echo "Saving done!"
	
	'if bIsUpgrade then
	'	SaveHyperVSettings HyperVFilePath
	'end if
	
	SaveStaticIPSettings(IPFilePath)
	
End Sub

'=======================================================================================
'
' Sub:  SaveSettings(ByVal strFname)
'		Save Adapter's, team's and VLAN's info. and settings info. to a text file.
'		Save Adapter's compatiblity settings. 
'  
'=======================================================================================
Sub IsIntelDevice(objNetDevicePhyObj,bIsLADIntelDevice)
	dim LastCapIndex
	dim index
	 	
    LastCapIndex=Ubound(objNetDevicePhyObj.Capabilities)
    For index = 0 to LastCapIndex-1
        if( objNetDevicePhyObj.Capabilities(index) = NCS_ADAPTER_CAP_BASIC_DMIX) then               
            bIsLADIntelDevice = true
        End if
        if( objNetDevicePhyObj.Capabilities(index) = NCS_ADAPTER_CAP_EXTENDED_DMIX) then               
            bIsLADIntelDevice = true  
    	End if
        if( objNetDevicePhyObj.Capabilities(index) = NCS_ADAPTER_CAP_VENDOR_INTEL) then
            if(bIsUpgrade) then               
            	bIsLADIntelDevice = True          
	    End if
        End if     
    Next
End Sub

'****************************************************************************
Private Function SaveAdapterInfo(objFile,objAdapter,DeviceIndex)
	dim LastCapIndex
	dim index,bFound 
	bFound = False
	
	LastCapIndex=Ubound(objAdapter.Capabilities)
	'objFile.WriteLine "Adapter Name=" & objAdapter.Caption 20/2/2004
	objFile.WriteLine "Adapter Name=" & objAdapter.OriginalDisplayName

	If bIsUpgrade Then
		'Save MAC address in config file for DMiX-to-DMiX upgrade scenarios only.
		objFile.WriteLine "Adapter PCIDeviceID=" & objAdapter.PermanentAddress
	Else
		objFile.WriteLine "Adapter PCIDeviceID=" & objAdapter.PCIDeviceID
	End if
	objFile.WriteLine "Adapter BusDeviceFunction=" & objAdapter.SlotID

	objFile.WriteLine "Adapter Index=" & DeviceIndex
	objFile.WriteLine "Private Description="
	objFile.Write "Adapter Capabilities=" 
	
	For index = 0 to LastCapIndex-1
		objFile.Write objAdapter.Capabilities(index) 
		objFile.Write ","
		if( objAdapter.Capabilities(index) = 50) then			
			bFound = True		
		End if	
	Next
	if bFound then
		isPowerManagementSupported = True
	Else
		isPowerManagementSupported = False	
	End if
	objFile.WriteLine objAdapter.Capabilities(LastCapIndex)
	objFile.WriteLine "Description=" & objAdapter.Description
End Function

'*****************************************************************************
Private Function CreateConfigFile(byVal strFileName)
	dim fso
	dim file
	
	Set fso = CreateObject("Scripting.FileSystemObject")
	Set file=fso.CreateTextFile(strFileName,True)
	Set CreateConfigFile=file
End Function

'*****************************************************************************
Private Function SaveAdvancedSettings(objFile,objAdapter,wbemServices)
	dim Perf_IANet_Obj_Name, Perf_IANet_Obj_Value, Perf_IANet_Obj_Desc, Perf_IANet_Obj_Exists
	dim szLLIPort
	dim szPortsList
	dim strQuery
	dim IANET_config
	dim IANet_Obj,OutParam
	dim oNamedValueSet
  	Set oNamedValueSet = CreateObject("WbemScripting.SWbemNamedValueSet")

  	oNamedValueSet.Add "GET_EXTENSIONS", true
  	oNamedValueSet.Add "GET_EXT_KEYS_ONLY", false
  	oNamedValueSet.Add "IANet_PartialData", 512

    ' We only want to skip DCB settings if its an upgrade and FCoE or iSCSI is being changed from the previous install state
    dim bSkipDcbSettings : bSkipDcbSettings = false
    if (bIsUpgrade=True) then
        ' Check if DCB or FCOE is being modified before saving the settings
        ' This needs to happen 
        dim oReg
        Set oReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")

        dim strKeyPath : strKeyPath = "SOFTWARE\INTEL\Prounstl"
        
        ' These flags are set by the MSI Custom action "CA_CHECK_IF_DCB_DEFAULTS_NEED_TO_BE_RESET" and designates when DCB defaults should be set
        dim strFcoeValueName : strFcoeValueName = "DCB_Update_FCoE"
        dim strIscsiValueName : strIscsiValueName = "DCB_Update_iSCSI"

        dim strFcoeValue
        oReg.GetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strFcoeValueName, strFcoeValue

        dim strIscsiValue
        oReg.GetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strIscsiValueName, strIscsiValue

        ' if strFcoeValue OR strIscsiValue is changing, we need to skip DCB settings so they aren't restored later
        
        if (strFcoeValue="1") OR (strIscsiValue="1") then 
            bSkipDcbSettings = true
        end if
    end if

	strQuery = "ASSOCIATORS OF {" & objAdapter.Path_.Path & "} WHERE ResultClass = IANet_AdapterSetting"
	Set IANet_config = wbemServices.ExecQuery(strQuery,,,oNamedValueSet)
				
	For Each IANet_Obj In IANet_config
			if (StrComp(IANet_Obj.Caption,"DCB_Settings")<>0) then ' DCB_Settings will be added later
				If (Is_GVRP_GMRP_Setting(IANet_Obj.Caption) = FALSE) AND (Is_StaticIP_Setting(IANet_Obj.Caption) = FALSE) Then  ' Don't save GVRP, GMRP or Static IP settings
				    if IANet_Obj.Description<>"DcbCfg" OR (IANet_Obj.Description="DcbCfg" AND bSkipDcbSettings=false) then ' Dont save DCB settings unless we're not to skip them (see above note)
					If  (StrComp(IANet_Obj.Caption,"PerformanceProfile")=0) Then 'Perf Profile saved to be written at end of setting saves
					    Perf_IANet_Obj_Exists = "True"
					    Perf_IANet_Obj_Name = "setting Name=" & IANet_Obj.Caption 			
					    on error resume next
						    Perf_IANet_Obj_Value = "setting Current Value=" & IANet_Obj.CurrentValue
						    if err then
							    szPortsList = ""
							    for each szLLIPort in IANet_Obj.CurrentValues
								    if StrComp(szLLIPort, " ", vbTextCompare) <> 0 then
									    szPortsList = szPortsList & szLLIPort & ","
								    end if
							    next
							    Perf_IANet_Obj_Value =  "setting Current Value=" & szPortsList
						    end if
					    on error goto 0
    					
					    Perf_IANet_Obj_Desc = "setting Description=" & IANet_Obj.Description
					Else
					    objFile.WriteLine "setting Name=" & IANet_Obj.Caption 			
					    on error resume next
						    objFile.WriteLine "setting Current Value=" & IANet_Obj.CurrentValue
						    if err then
							    szPortsList = ""
							    for each szLLIPort in IANet_Obj.CurrentValues
								    if StrComp(szLLIPort, " ", vbTextCompare) <> 0 then
									    szPortsList = szPortsList & szLLIPort & ","
								    end if
							    next
							    objFile.WriteLine "setting Current Value=" & szPortsList
						    end if
					    on error goto 0
    				
					    objFile.WriteLine "setting Description=" & IANet_Obj.Description
					End If
				    end if
				End If
			end if		
	Next	

	strQuery = "SELECT * FROM IANet_AdapterSetting where ParentID='" & objAdapter.DeviceID & "' AND GroupID=12"
	set IANet_config = wbemServices.ExecQuery(strQuery,,,oNamedValueSet)
	For Each IANet_Obj In IANet_config
		objFile.WriteLine "setting Name=" & IANet_Obj.Caption 			
		objFile.WriteLine "setting Current Value=" & IANet_Obj.CurrentValue
		objFile.WriteLine "setting Description=" & IANet_Obj.Description
		exit for
	Next	
		
	'Power Saver

	if (isPowerManagementSupported = True) Then	
		' Some older versions of DMXI do not support all these power 
		' management options so we need to move on if there is a failure
		on error resume next

		Set OutParam = objAdapter.ExecMethod_("GetPowerUsageOptions")
		if isnull(OutParam.AutoPowerSaveModeEnabled) Then	
		else
			objFile.WriteLine"setting Name=AutoPowerSaveModeEnabled"
    			objFile.WriteLine"setting Current Value=" & OutParam.AutoPowerSaveModeEnabled
    			objFile.WriteLine"setting Description=AutoPowerSaveModeEnabled"
    		End If
		if isnull(OutParam.ReduceSpeedOnPowerDown) Then	
		else
			objFile.WriteLine"setting Name=ReduceSpeedOnPowerDown"
    			objFile.WriteLine"setting Current Value=" & OutParam.ReduceSpeedOnPowerDown
    			objFile.WriteLine"setting Description=ReduceSpeedOnPowerDown"
    		End If
		if isnull(OutParam.SmartPowerDown)Then    
		else    		   
	   		objFile.WriteLine"setting Name=SPDEnabled"
			objFile.WriteLine"setting Current Value=" & OutParam.SmartPowerDown
			objFile.WriteLine"setting Description=SmartPowerDown"
		End If
		if isnull(OutParam.SavePowerNowEnabled) Then	
		else
			objFile.WriteLine"setting Name=SavePowerNowEnabled"		
			objFile.WriteLine"setting Current Value=" & OutParam.SavePowerNowEnabled
			objFile.WriteLine"setting Description=SavePowerNowEnabled"
		End If
		if isnull(OutParam.EnhancedASPMPowerSaver) Then	
		else
			objFile.WriteLine"setting Name=EnhancedASPMPowerSaver"		
			objFile.WriteLine"setting Current Value=" & OutParam.EnhancedASPMPowerSaver
			objFile.WriteLine"setting Description=EnhancedASPMPowerSaver"
		End If

		' Turn error checking back on
		on error goto 0
		
	End If

	'The performance profile needs to be set as the last item so that it sets the correct profile
	If  (StrComp(Perf_IANet_Obj_Exists ,"True")=0) Then
		objFile.WriteLine Perf_IANet_Obj_Name
		objFile.WriteLine Perf_IANet_Obj_Value
		objFile.WriteLine Perf_IANet_Obj_Desc
		Perf_IANet_Obj_Exists = "False"
	End If	

End Function

'*****************************************************************************
Private Function SaveTeamInfo(objFile,objNetDeviceLogObj,DeviceIndex,wbemServices)
 	dim colTeamedAdapters,colTeamedMemberAdapter,colTeam
 	dim TeamedAdapter,TeamedMemberAdapter,objTeam    
    	dim strQuery
 

    'Access the same Team from IANet_TeamOfAdapters 
    strQuery="ASSOCIATORS OF {" & objNetDeviceLogObj.Path_.Path & "} where ResultRole=SameElement"
	Set colTeam = wbemServices.ExecQuery(strQuery)
	
    For Each objTeam In colTeam 'only one team in this collection    	
	    	
	    	' The team prefix to the name has now been localized so we can no longer assume the prefix is "TEAM : "
	    	' Get the localized prefix from the MOF file to extract the user's name
	    	objFile.WriteLine "Team Name=" & ExtractTeamPrefixFromTeamName(objTeam.Caption)
	    	
		objFile.WriteLine "Description=" & objTeam.Description
		objFile.WriteLine "Team Settings Index=" & DeviceIndex				
		'Get Team Mode and Adapter count
		objFile.WriteLine "Team Type=" & objTeam.TeamingMode
		
		objFile.WriteLine "Adapter Count=" & objTeam.AdapterCount	
		objFile.WriteLine "MFOEnabled=0"

		'Access Members of this Team
		
		strQuery="ASSOCIATORS OF {" & objTeam.Path_.Path & "} where ResultRole=PartComponent"   
		Set colTeamedAdapters = wbemServices.ExecQuery(strQuery) 		
		For Each TeamedAdapter In colTeamedAdapters
		'	'objFile.WriteLine "Member Adapter="&TeamedAdapter.Caption	
			objFile.WriteLine "Member Adapter="&TeamedAdapter.OriginalDisplayName
			If bIsUpgrade Then
				objFile.WriteLine "Member PCIDeviceID="&TeamedAdapter.PermanentAddress	'Save MAC address in config file for upgrade scenarios only.
			Else
				objFile.WriteLine "Member PCIDeviceID="&TeamedAdapter.PCIDeviceID
			End if
			
			objFile.WriteLine "Member BusDeviceFunction="&TeamedAdapter.SlotID	'Save Bus/device/function ID
			
			'Get Priority settings for this member adapter
			strQuery="REFERENCES OF {" & TeamedAdapter.Path_.Path & "} where ResultClass=IANet_TeamedMemberAdapter"
			Set colTeamedMemberAdapter= wbemServices.ExecQuery(strQuery)
			For Each TeamedMemberAdapter In colTeamedMemberAdapter
				objFile.WriteLine "-Preferred Priority Setting="&TeamedMemberAdapter.AdapterFunction
				' parse out just the device ID of the TEAM and ADAPTER
				'objFile.WriteLine "-Group Comp Setting=" + Mid(TeamedMemberAdapter.GroupComponent,(instr(TeamedMemberAdapter.GroupComponent,"{")+1),36)
				objFile.WriteLine "-Part Comp Setting=" + Mid(TeamedMemberAdapter.PartComponent,(instr(TeamedMemberAdapter.PartComponent,"{")+1),36)
			Next	
		Next	
	Next
End Function		

'///////////////////////////////////////////////////////////////////////////////
'// FUNCTION NAME	: ExtractTeamPrefixFromTeamName
'//
'// DESCRIPTION	    	: Call this function to determine what is the spelling						
'//			: of the localized team prefix.  Then extract this 
'//			: portion from the string passed in.  
'// PARAMETERS		: String - value returned from IANET_TeamOfAdapters.Caption 
'// RETURN		: String - the caption without the team prefix
'///////////////////////////////////////////////////////////////////////////////
Private Function ExtractTeamPrefixFromTeamName(szWholeTeamName)
'
	'Wscript.echo "Entering - ExtractTeamPrefixFromTeamName - input ->" + szWholeTeamName + "<-"
	On Error Resume Next
	Err.Clear
	Const wbemFlagUseAmendedQualifiers = &h20000
	Dim wbemServices
	Dim ObjClass
	Dim ColProperties
	Dim ObjProperties
	Dim ColQualifiers
	Dim ObjQualifiers
	Dim szTeamPrefix : szTeamPrefix = ""
	
	Set wbemServices = GetObject("winmgmts:{impersonationLevel=impersonate}//./root/IntelNcs2")	
	wbemServices.Security_.Privileges.AddAsString "SeLoadDriverPrivilege", True
	Set ObjClass = wbemServices.Get("IANet_TeamOfAdapters",wbemFlagUseAmendedQualifiers)
    
    	Set ColProperties = ObjClass.Properties_
    	Set ObjProperties = ColProperties.Item("TeamPrefix")
    	If Err Then
		'Wscript.echo "TeamPrefix not found"
		If (InStr(szWholeTeamName,"TEAM : ")) Then
			szWholeTeamName = Mid(szWholeTeamName,(Len("TEAM : ") + 1))
		End If
		'Wscript.echo "Exiting - ExtractTeamPrefixFromTeamName - output ->" + szWholeTeamName + "<-"
    		ExtractTeamPrefixFromTeamName = szWholeTeamName
		exit function
    	End If 
    	Err.Clear
    	
    	Set ColQualifiers = ObjProperties.Qualifiers_
    	Set ObjQualifiers = ColQualifiers.Item("Values")
    	If Err Then
		'Wscript.echo "Values not found"
		If (InStr(szWholeTeamName,"TEAM : ")) Then
			szWholeTeamName = Mid(szWholeTeamName,(Len("TEAM : ") + 1))
		End If
		'Wscript.echo "Exiting - ExtractTeamPrefixFromTeamName - output ->" + szWholeTeamName + "<-"
    		ExtractTeamPrefixFromTeamName = szWholeTeamName
		exit function
    	End If 
  
	If VarType(ObjQualifiers.Value) = (vbVariant + vbArray) Then
		szTeamPrefix = ObjQualifiers.Value(LBound(ObjQualifiers.Value))
	Else
		szTeamPrefix = ObjQualifiers.Value
	End If
	
	If (Len(szTeamPrefix) < 1)Then
		szTeamPrefix = "TEAM : "
	End If
	
	'Wscript.echo "Team prefix is ->" + szTeamPrefix + "<-"
	
	If (InStr(szWholeTeamName,szTeamPrefix)) Then
		szWholeTeamName = Mid(szWholeTeamName,(Len(szTeamPrefix) + 1))	
	ElseIf (InStr(szWholeTeamName,"TEAM : ")) Then
		szWholeTeamName = Mid(szWholeTeamName,(Len("TEAM : ") + 1))
	End If
	
	'Wscript.echo "Exiting - ExtractTeamPrefixFromTeamName - output ->" + szWholeTeamName + "<-"
	
	ExtractTeamPrefixFromTeamName = szWholeTeamName
'
End Function

'*****************************************************************************
Private Function SaveTeamAdvancedSettings(objFile,objNetDevicelogObj,wbemServices)
	Dim IANet_config
	Dim IANet_Obj

	Set IANet_config = wbemServices.ExecQuery("ASSOCIATORS OF {" & objNetDeviceLogObj.Path_.Path & "} WHERE ResultClass = IANet_TeamSetting")
	For Each IANet_Obj In IANET_config
		If (Is_GVRP_GMRP_Setting(IANet_Obj.Caption) = FALSE) AND _
			(Is_ConnMon_Setting(IANet_Obj.Caption) = FALSE) AND _ 
			(Is_StaticIP_Setting(IANet_Obj.Caption) = FALSE) Then  ' Don't save GVRP, GMRP or Static IP settings
			objFile.WriteLine "setting Name=" & IANet_Obj.Caption                             
			objFile.WriteLine "setting Current Value=" & IANet_Obj.CurrentValue
			objFile.WriteLine "setting Description=" & IANet_Obj.Description
		End If
	Next	
End Function

'*****************************************************************************
Private Function SaveVlanSettings(objFile,objAdapter,wbemServices)
	Dim strQuery
	Dim IANet_802dot1VLANService,IANet_VLANSet
	Dim IANet_802dot1VLANObj,IANet_VLANObj
	Dim UntaggedVLANObj
	Dim isUntaggedVLANPresent
	
	strQuery = "ASSOCIATORS OF {" & objAdapter.Path_.Path & "} WHERE ResultClass = IANet_802dot1QVLANService"
	Set IANet_802dot1VLANService = wbemServices.ExecQuery(strQuery)
	If IANet_802dot1VLANService.Count <> 0 Then 
		For Each IANet_802dot1VLANObj In IANet_802dot1VLANService	      
			strQuery = "ASSOCIATORS OF {" & IANet_802dot1VLANObj.Path_.Path & "} WHERE ResultClass = IANet_VLAN"
			Set IANet_VLANSet = wbemServices.ExecQuery(strQuery)
			
			If IANet_VLANSet.Count > 0 Then
				isUntaggedVLANPresent = False
				
				For Each IANet_VLANObj In IANet_VLANSet
					If IANet_VLANObj.VLANNumber <> 0 Then
						objFile.WriteLine "VLAN Name=" & IANet_VLANObj.VLANName
						objFile.WriteLine "VLAN Id=" & IANet_VLANObj.VLANNumber
						SaveVLANAdvancedSettings objFile,IANet_VLANObj,wbemServices
					Else
						Set UntaggedVLANObj = IANet_VLANObj
						isUntaggedVLANPresent = True
					End If
				Next
				
				If isUntaggedVLANPresent = True Then
					objFile.WriteLine "VLAN Name=" & UntaggedVLANObj.VLANName
					objFile.WriteLine "VLAN Id=" & UntaggedVLANObj.VLANNumber
					SaveVLANAdvancedSettings objFile,UntaggedVLANObj,wbemServices
				End If
			End If
		Next
	End If
End Function
	
'*****************************************************************************
Private Function SaveVLANAdvancedSettings(objFile,objNetDeviceLogObj,wbemServices)
	Dim IANet_config
	Dim IANet_Obj
	
	Set IANet_config = wbemServices.ExecQuery("ASSOCIATORS OF {" & objNetDeviceLogObj.Path_.Path & "} WHERE ResultClass = IANet_VLANSetting")
	For Each IANet_Obj In IANet_config
		If (Is_GVRP_GMRP_Setting(IANet_Obj.Caption) = FALSE) AND _
			(Is_ConnMon_Setting(IANet_Obj.Caption) = FALSE) AND _ 
			(Is_StaticIP_Setting(IANet_Obj.Caption) = FALSE) Then  ' Don't save GVRP, GMRP or Static IP settings
			objFile.WriteLine "setting Name=" & IANet_Obj.Caption                             
			objFile.WriteLine "setting Current Value=" & IANet_Obj.CurrentValue
			objFile.WriteLine "setting Description=" & IANet_Obj.Description
		End If
	Next	
End Function

'=====================================================================================
'
' Sub:	RestoreSettings(ByVal strFname)
'		Call subs to read file to get all the info. about adapter, Team and VLANs.
'		If there are the same number of adapters as settings then 
'		it will apply the saved settings, as long as the adapters are the same type.  
'		If the adapter is a different type, compatibility
'		is determined by local network speed.  Then applicable settings are applied.
'		If number of settings and adapters are mismatched, user is prompted for selection
'   
'=====================================================================================
Sub RestoreSettings(ByVal strFname)
	Dim strTeamName
	Dim SplitID,SysAdapterID,FileAdapterID

	bError = FALSE

	isTimeOutValueModified = false
	GetOldTimeOutValue()	
	
	'Read File and assign found values to Teams() and Adapters()
	ReadFile(strFname)

	If bError = FALSE Then

	if StrComp(strOS, OSVersion, vbTextCompare) <> 0 then
 		wscript.echo "Cannot restore the settings for Intel(R) Network Connections because,"
		wscript.echo "the current version of Windows(R) doesn't match the version used to create the configuration file."
		wscript.echo "Current version of Windows:  " & OSVersion
		wscript.echo "Config File Windows version: " & strOS
		exit sub
	end if

	'Set the OemCustomizeable registry setting
	RestoreOemCustomizeableSetting(strOEMCustomizeableValue)
	'Remove any existing Teams and VLANs.
	Remove()
	'Create single session to make changes..
	CreateSessions() 
	ValidateAdapters()

	on error resume next
	Set test = wbemServices.Get("IANet_LogicalEthernetAdapter")

	if err < 0  then 
		wscript.echo "Unable to enumerate Advanced Network Service information, ANS might not be present on system"
		wscript.echo "Teams and VLAN information contained in the configuration file will not attempt to be restored."
		bNoAns = true
	end if

	on error goto 0 

          dim bIsLADIntelDevice
          dim LastCapIndex

	'Cycle as many times as adapter sets in file, check selection and compatibility, then apply
	       For Each AdapterObj in AdapterSets
               		bIsLADIntelDevice = false

			IsIntelDevice AdapterObj, bIsLADIntelDevice    

               For index = 0 to (totalAdapters - 1)
                    strAdapterName = Adapters(index, 1, 0)               'Adapter Name
                    strAdapterPCIDeviceID = Adapters(index, 1, 1)     'Adapter PCIDeviceID or PermanentAddress
                    strCapabilities = Adapters(index, 2, 0)               'Capabilities
                    strOrgDispName = Adapters(index, 2, 1)               'Original Display Name
                    strSettingsIndex = Adapters(index, 3, 0)          'Setting Index
		    strAdapterBDF = Adapters(index, 4, 0)          'Bus/device/function
               
                    If bMisMatch = TRUE Then
                         CheckSelected strSettingsIndex
                         If bUserInput = TRUE Then
                              If bSelected = TRUE Then
                                   If strAdapterName = AdapterObj.Caption Then     
                                        If ((Adapters(index, 0, 1) <> 1) AND bIsLADIntelDevice) Then                                                                                                     
                                             ApplyAdapterSettings(strSettingsIndex)                                                  
                                             Exit For
                                        End If
                                   End If
                              End If
                         End If
                    Else
			 If bBdfRestore = TRUE then
			 	'Compare only the first three parts of the deviceID (excludes the rev)
				'Get all the parts in an array split by &
				SplitID = Split(AdapterObj.PCIDeviceID,"&")
				'Re-initialize SplitID saving only the first three (saving array elements 0-2)
				ReDim Preserve SplitID(2)
				'concatinate the three parts back together with & back in the middle
				SysAdapterID = Join(SplitID,"&")
				'Do the same for the file device id
				SplitID = Split(strAdapterPCIDeviceID,"&")
				ReDim Preserve SplitID(2)
				FileAdapterID = Join(SplitID,"&")

				If ((StrComp(AdapterObj.SlotID, strAdapterBDF) = 0) AND (StrComp(SysAdapterID, FileAdapterID) = 0)) Then
                              		If ((Adapters(index, 0, 1) <> 1) AND bIsLADIntelDevice) Then  
                                   		ApplyAdapterSettings(strSettingsIndex)                                                                                               
                                   		Exit For
                              		End If
				End If
			 Else
                         	If strAdapterName = AdapterObj.Caption Then
                              		If ((Adapters(index, 0, 1) <> 1) AND bIsLADIntelDevice) Then 
                                   		ApplyAdapterSettings(strSettingsIndex)                                                                                               
                                   		Exit For
                              		End If
                         	Elseif (bIsUpgrade = True) AND (strAdapterPCIDeviceID = AdapterObj.PermanentAddress) AND (AdapterObj.PermanentAddress <> "") Then
                              		If ((Adapters(index, 0, 1) <> 1) AND bIsLADIntelDevice) Then 
                                  		ApplyAdapterSettings(strSettingsIndex)                                                                                               
                                   		Exit For
                              		End If
                         	Elseif (bIsUpgrade = False) AND (strAdapterPCIDeviceID = AdapterObj.PCIDeviceID) AND (AdapterObj.PCIDeviceID <> "") Then
                              		If ((Adapters(index, 0, 1) <> 1) AND bIsLADIntelDevice) Then 
                                   		ApplyAdapterSettings(strSettingsIndex)                                                                                               
                                   		Exit For
                              		End If
                         	End If
			 End If
                    End If
               Next                    
          Next     
		ExecApply wbemServices, strNetSerObjPath, SessionObject	'SCR 37163

		if bNoAns<>true then
			For index = 0 to (totalTeams - 1)
				strSettingsIndex = Teams(index, 1, 2)
				strTeamName = Teams(index, 0, 0)
				If bMisMatch = TRUE Then
					'Sets bSelected
					CheckSelected strSettingsIndex
					If bSelected = TRUE Then					
						ApplyTeamSettings(strSettingsIndex)					
					End If			
				Else
					ApplyTeamSettings(strSettingsIndex)								
				End If
			Next
		end if
		
		If bNewTeam  = TRUE Then
			WScript.Echo "New team(s) were created based on config file"
		ElseIf bModified = TRUE  Then
			WScript.Echo "New Settings were applied!"
		ElseIf bUserInput = TRUE Then
			WScript.Echo "No new settings were applied.  Any existing teams were deleted."
		Else
			WScript.Echo "No new settings were applied.  Any existing teams were deleted."
		End If

	ElseIf bError = TRUE Then
		Exit Sub
	End If

	'ReleaseHandle wbemServices, strNetSerObjPath, SessionObject
	
	'if bIsUpgrade then
	'	RestoreHyperVSettings HyperVFilePath
	'end if 

	RestoreStaticIPSettings(IPFilePath)
    
    RestoreWINSSettings(WINSFilePath)
	
	ShowTimeOutValueRebootMessage()

End Sub
	
'=====================================================================================
'
' Sub:	Sub ExecApply(ByVal wbemServices, ByVal strNetSerObjPath, ByVal SessionObject)
'  
'=====================================================================================
Sub ExecApply(ByVal wbemServices, ByVal strNetSerObjPath, ByVal SessionObject)
	Dim StdOut,oReg,strComputer,strKeyPath,strValueName,strValue
		
	Set NetServiceObject = wbemServices.Get(strNetSerObjPath)
	Set FinalTargetobj = NetServiceObject.ExecMethod_("Apply", SessionObject)
	'WScript.Echo "FinalTargetobj.FollowupAction" & FinalTargetobj.FollowupAction
	if FinalTargetobj.FollowupAction = 1 Then
		WScript.Echo "FinalTargetobj.FollowupAction" & FinalTargetobj.FollowupAction
		strComputer = "."
		Set StdOut = WScript.StdOut
		Set oReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\" &_ 
		strComputer & "\root\default:StdRegProv")
		strKeyPath ="SOFTWARE\INTEL\Network_Services\DMIX"
		strValueName = "RebootReq"
		strValue = "1"
		oReg.SetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue
	End if
End Sub

'=====================================================================================
'
' Sub:	Sub ReleaseHandle(ByVal wbemServices, ByVal strNetSerObjPath, ByVal SessionObject)
'  
'=====================================================================================
Sub ReleaseHandle(ByVal wbemServices, ByVal strNetSerObjPath, ByVal SessionObject)
	WScript.Echo "Releasing Session Handle"
	Set NetServiceObject = wbemServices.Get(strNetSerObjPath)
	Set FinalTargetobj = NetServiceObject.ExecMethod_("Apply", SessionObject)
End Sub

'==================================================================================================
'
' CreateSessions()
' Create sessions to make settings changes
'
'==================================================================================================

Sub CreateSessions()
	Dim IANet_NetServiceClassDescription,cstring
	Dim Method 
	Dim ServiceObject,TempObj
	Set wbemServices = GetObject("winmgmts:{impersonationLevel=impersonate}//./root/IntelNcs2")	
	' SCR fix for 38688 and 39528
	wbemServices.Security_.Privileges.AddAsString "SeLoadDriverPrivilege", True
	Set IANet_NetServiceClassDescription = wbemServices.Get("IANet_NetService")
	Set SessionObject = IANet_NetServiceClassDescription.Methods_.Item("Apply").InParameters.SpawnInstance_()  
	
	Set SValueSet = CreateObject("WbemScripting.SWbemNamedValueSet")
	Set NetServiceSet = wbemServices.InstancesOf("IANet_NetService")

	For Each NetServiceObject In NetServiceSet	
		strNetSerObjPath = NetServiceObject.Path_.Path	
		Set Method = NetServiceObject.Methods_("BeginApply")			' Save the path for later use
		Set ServiceObject = NetServiceObject.ExecMethod_("BeginApply")
		If ServiceObject.returnValue = 0 Then
			cstring = ServiceObject.ClientSetHandle
		End If
	
	Next
	
	SValueSet.Add "ClientSetId", cstring
	SessionObject.ClientSetHandle = cstring	

	Set AdapterSets = wbemServices.InstancesOf("IANet_PhysicalEthernetAdapter",,SValueSet)	

End Sub

'======================================================================================
'
' Sub ValidateInput(ByVal strInput)
'Validate input by removing any spaces or periods in strInput, returns strChoices
'========================================================================================
Sub ValidateInput(ByVal strInput)
	Dim i, ii, arrChoices
	arrChoices = Split(strInput, ",")
	For i = 0 to Ubound(arrChoices)
		arrChoices(i) = Trim(arrChoices(i))
		If Right(arrChoices(i), 1) = "." Then
			arrChoices(i) = Replace(arrChoices(i), ".", "")
		End If
	Next
	strChoices = Join(arrChoices, ",")
End Sub

'=================================================================================================
'
' Sub ReadFile(ByVal strFname)
' Read File and assign found values to Adapters() and Teams() arrays
'
'=================================================================================================
Sub ReadFile(ByVal strFname)
	Dim v, i, ii, x, fso, strAdapterName ,w
	Dim strAdapterCaps, strNewAdapterName, strPCIDeviceID, strAdapterIndex, strBusDeviceFunction 
	Dim strCapabilities, strSettingsSet, arrSettingsSets
	Dim strIsDefault, ts, strLine, z, numVLANS, numTVLANS
	dim firstVlanIndex : firstVlanIndex = -1	
	Set fso = CreateObject("Scripting.FileSystemObject")
	If fso.FileExists (strFname) <> True Then
		Wscript.Echo "The configuration file can not be found or is"
		Wscript.Echo "not in the same directory as SavResDX.vbs."
		WScript.Echo "Try using full pathname to the configuration file."
		bError = TRUE
		Exit Sub
	Else
	
		' Array Adapters holds all the info. about the adapter's and related VLANs info.
		' Adapters( , 0, 0) is a flag of Adapter's existence
		' Adapters( , 0, 1) is a flag for setting having been applied
		' Adapters( , 0, 2) is Number of VLANS on Adapter
		' Adapters( , 1, 0) is Adapter's Name
		' Adapters( , 1, 1) is Adapter's PCIDeviceID or PermanentAddress
		' Adapters( , 2, 0) is Adapter's Capabilities
		' Adapters( , 2, 1) is Adapter's Original Display Name (for Express Teaming)
		' Adapters( , 3, 0) is Settings Index, for selecting settings sets
		' Adapters( , 3, 1) is Settings Default, "TRUE" or "FALSE" for selecting settings sets
		' Adapters( , 4, 0) is Bus/device/function for upgrades
		' Adapters( , 5, 0) is Adapter's Setting Name 
		' Adapters( , 5, 1) is Adapter's Setting value
		'
		' Adapters( , x, 0) is Keyword "VLAN", any elements after this keyword are VLAN's setting name and value 
		
		Redim Adapters(maxAdapterTeam, maxSettings, 5)  
		
		' Array Teams holds all the info. about the Team's and related VLANs info.
		' Teams( , 0, 0) is Team's Name
		' Teams( , 0, 1) is a flag for setting having been applied
		' Teams( , 0, 2) is number of VLANS on Team
		' Teams( , 1, 0) is Team's Type
		' Teams( , 1, 1) is Team's Adapter Count
		' Teams( , 1, 2) is Teams Settings Index for user selection
		
		' Teams( , 2, 0) is keyword "MemberAdapter", 
		' Teams( , 2, 1) is Member adapter's caption
		' Teams( , 2, 2) is Member adapter's flag for client(0) or server(1) property
		' Teams( , 2, 3) is Member adapter's Preferred Priority Setting
		' Teams( , 2, 4) is Member adapter's flag for "Already Added to Team" (1 or 0)
		' Teams( , 2, 5) is Member adapter's PCIDeviceID or PermanentAddress
		' Teams( , 2, 6) is Member adapter's Bus/Device/Function ID
		'
		' Teams( , x, 0) is keyword "MemberAdapter", 
		' Teams( , x, 1) is related adapter's caption
		' Teams( , x+1, 0) is Teams's Setting Name; Teams( , x+1, 1) is team's Setting value
		' Teams( , y, 0) is Keyword "VLAN", any elements after this keyword are VLAN's setting name and value 
		Redim Teams(maxAdapterTeam, maxSettings, 10)  

		totalAdapters = 0
		totalTeams = 0

		' Read the text file and save all the info. to two arrays - Adapters() & Teams()
		Set ts = fso.OpenTextFile(strFname, 1)
		ii = 0
		v = 0
		x = 0
		w=0
		Do Until ts.AtEndOfStream
			
			
			ReDim Preserve arrPrivDesc(v + 1)
			ReDim Preserve arrTeamPrivDesc(x + 1)
			strLine = ts.ReadLine()
			If StrComp(Mid(strLine, 1, 13), "Adapter Name=", vbTextCompare) = 0 Then
				numVLANS = 0  
				strNewAdapterName = Mid(strLine, 14)
				strLine = ts.ReadLine()
				If StrComp(Mid(strLine, 1, 20), "Adapter PCIDeviceID=", vbTextCompare) = 0 Then
					strPCIDeviceID = Mid(strLine, 21)
					strLine = ts.ReadLine()
				End If
				If StrComp(Mid(strLine, 1, 26), "Adapter BusDeviceFunction=", vbTextCompare) = 0 Then
					strBusDeviceFunction = Mid(strLine, 27)
					strLine = ts.ReadLine()
				End If
				If StrComp(Mid(strLine, 1, 14), "Adapter Index=", vbTextCompare) = 0 Then
					strAdapterIndex = Mid(strLine, 15)
					strLine = ts.ReadLine()	
				End If
				If StrComp(Mid(strLine, 1, 20), "Private Description=", vbTextCompare) = 0 Then
					arrPrivDesc(v) = Mid(strLine, 21) 
					strLine = ts.ReadLine()
					v = v + 1
				End If
				If StrComp(Mid(strLine, 1, 21), "Adapter Capabilities=", vbTextCompare) = 0 Then
					strCapabilities =Mid(strLine, 22)
					strLine = ts.ReadLine()
				End If
				strLine = ts.ReadLine()		'Skip Description line.
				If StrComp(Mid(strLine, 1, 22), "Original Display Name=", vbTextCompare) = 0 Then
					strOrgDispName = Mid(strLine, 23)	'For Express Teaming
					strLine = ts.ReadLine()
				End If
				
				'Assign found values to array"
				Adapters(totalAdapters, 1, 0) = strNewAdapterName
				Adapters(totalAdapters, 1, 1) = strPCIDeviceID
				Adapters(totalAdapters, 2, 0) = strCapabilities
				Adapters(totalAdapters, 2, 1) = strOrgDispName		'For Express Teaming
 		   		Adapters(totalAdapters, 3, 0) = strAdapterIndex              
				Adapters(totalAdapters, 3, 1) = strIsDefault
				Adapters(totalAdapters, 4, 0) = strBusDeviceFunction
				
				'assigning settings values"
				i = SETTINGS_INDEX		
				
				'SCR 40856
				'strLine = ts.ReadLine() 
				Do while StrComp(strLine, "", vbTextCompare) <> 0
					If StrComp(Mid(strLine, 1, 13), "Setting Name=", vbTextCompare) = 0 Then
						If ( Is_GVRP_GMRP_Setting(strLine) = FALSE ) Then
							
							If StrComp(Mid(strLine, 14), "TimeOutValue", vbTextCompare) = 0 Then
								isTimeOutValueModified = true
							End If
							
							Adapters(totalAdapters, i, 0) = Mid(strLine, 14)	'Setting Name
							strLine = ts.ReadLine()
							Adapters(totalAdapters, i, 1) = Mid(strLine, 23)	'Setting Value
							i = i + 1
						Else
							strLine = ts.ReadLine() 'skip the next line if GVRP or GMRP
						End If
						strLine = ts.ReadLine()			' Skip the description
						
					ElseIf StrComp(Mid(strLine, 1, 10), "VLAN Name=", vbTextCompare) = 0 Then
						Do while StrComp(strLine, "", vbTextCompare) <> 0
							Adapters(totalAdapters, i, 0) = "VLAN"				'Set up keyword for searching VLAN later
							numVLANS = numVLANS + 1
							Adapters(totalAdapters, 0, 2) = numVLANS
							Adapters(totalAdapters, i+1, 0) = Mid(strLine, 11)	'VLAN Name
							strLine = ts.ReadLine()
							Adapters(totalAdapters, i+2, 0) = Mid(strLine, 9)	'VLAN ID
							i = i + 3
							strLine = ts.ReadLine()
							Do While StrComp(Mid(strLine, 1, 10), "VLAN Name=", vbTextCompare) <> 0
								If StrComp(Mid(strLine, 1, 13), "Setting Name=", vbTextCompare) = 0 Then
									If ( Is_GVRP_GMRP_Setting(strLine) = FALSE ) Then
										Adapters(totalAdapters, i, 0) = Mid(strLine, 14)	'Setting Name
										strLine = ts.ReadLine()									
										Adapters(totalAdapters, i, 1) = Mid(strLine, 23)	'Setting Value
									Else
										strLine = ts.ReadLine() 'skip the next line if GVRP or GMRP
									End If
									strLine = ts.ReadLine()
								End If
								If strLine <> "" Then
									strLine = ts.ReadLine()
									i = i + 1
								Else
									Exit Do
								End If
							Loop
						Loop
					End If  
					If StrComp(strLine, "", vbTextCompare) <> 0 Then
						strLine = ts.ReadLine()
					End If
				Loop
				totalAdapters = totalAdapters + 1
			ElseIf StrComp(Mid(strLine, 1, 10), "Team Name=", vbTextCompare) = 0 Then
				Teams(totalTeams, 0, 0) = Mid(strLine, 11)
				strLine = ts.ReadLine()
				strLine = ts.ReadLine()	'Skip Description line
				If StrComp(Mid(strLine, 1, 20), "Team Settings Index=", vbTextCompare) = 0 Then
					Teams(totalTeams, 1, 2) = Mid(strLine, 21)
					strLine = ts.ReadLine()
				End If
				If StrComp(Mid(strLine, 1, 10), "Team Type=", vbTextCompare) = 0 Then
					Teams(totalTeams, 1, 0) = Mid(strLine, 11)
					strLine = ts.ReadLine()
				End If
				If StrComp(Mid(strLine, 1, 14), "Adapter Count=", vbTextCompare) = 0 Then
					Teams(totalTeams, 1, 1) = Mid(strLine, 15)
					strLine = ts.ReadLine()
				End If			
			
				'Added for MFO on 17th Feb
				If StrComp(Mid(strLine, 1, 11), "MFOEnabled=", vbTextCompare) = 0 Then
					'bMFOEnabled =Mid(strLine, 12)
					Teams(totalTeams, 1, 3)=Mid(strLine, 12)						
					strLine = ts.ReadLine()					
				Else
					Teams(totalTeams, 1, 3)=0
				End If 
				
				If StrComp(Mid(strLine, 1, 20), "Private Description=", vbTextCompare) = 0 Then
					arrTeamPrivDesc(x) = Mid(strLine, 21)
					x = x + 1
					strLine = ts.ReadLine()
				End If				
				i = 2				
				Dim AdapterInTeamOffset: AdapterInTeamOffset = 0
				Do While StrComp(Mid(strLine, 1, Len("Member Adapter=")), "Member Adapter=", vbTextCompare) = 0		

					TeamedMemberAdapterName(totalTeams, AdapterInTeamOffset) = Mid(strLine,(instr(strLine,"=") + 1))
					Dim vi
					Teams(totalTeams, i, 0) = "MemberAdapter"
					Teams(totalTeams, i, 1) = Mid(strLine, 16)

					strLine = ts.Readline()


					If StrComp(Mid(strLine, 1, Len("Member PCIDeviceID=")), "Member PCIDeviceID=", vbTextCompare) = 0 Then
						TeamedMemberAdapterPCIDeviceID(totalTeams, AdapterInTeamOffset) = Mid(strLine,(instr(strLine,"=") + 1))
						Teams(totalTeams, i, 5) = Mid(strLine, 20)			
						strLine = ts.Readline()
					End If
					If StrComp(Mid(strLine, 1, Len("Member BusDeviceFunction=")), "Member BusDeviceFunction=", vbTextCompare) = 0 Then
						TeamedMemberAdapterBDF(totalTeams, AdapterInTeamOffset) = Mid(strLine,(instr(strLine,"=") + 1))
						Teams(totalTeams, i, 6) = Mid(strLine, 26)			
						strLine = ts.Readline()
					End If
					If StrComp(Mid(strLine, 1, Len("-Preferred Priority Setting=")), "-Preferred Priority Setting=", vbTextCompare) = 0 Then
						TeamedMemberAdapterPreferredPrimarySetting(totalTeams, AdapterInTeamOffset) = Mid(strLine,(instr(strLine,"=") + 1))
						strLine = ts.ReadLine()
						Teams(totalTeams, i, 3) = Mid(strLine, 29)

					End If
					'If StrComp(Mid(strLine,1,Len("-Group Comp Setting=")),"-Group Comp Setting=",vbTextCompare) = 0 Then
					'	TeamedMemberAdapterGroupComponentSetting(totalTeams, AdapterInTeamOffset) = Mid(strLine,(instr(strLine,"=") + 1))
					'	strLine = ts.ReadLine()
					'End If
					If StrComp(Mid(strLine,1,Len("-Part Comp Setting=")),"-Part Comp Setting=",vbTextCompare) = 0 Then
						TeamedMemberAdapterPartComponentSetting(totalTeams, AdapterInTeamOffset) = Mid(strLine,(instr(strLine,"=") + 1))
						strLine = ts.ReadLine()
					End If					
					AdapterInTeamOffset = AdapterInTeamOffset + 1
					i = i + 1
				Loop
				
				Do while StrComp(strLine, "", vbTextCompare) <> 0					
					If StrComp(Mid(strLine, 1, 13), "Setting Name=", vbTextCompare) = 0 Then
						If ( Is_GVRP_GMRP_Setting(strLine) = FALSE ) Then
							Teams(totalTeams, i, 0) = Mid(strLine, 14)	'Setting Name
							strLine = ts.ReadLine()						
							Teams(totalTeams, i, 1) = Mid(strLine, 23)	'Setting Value						
							i = i + 1
						Else
							strLine = ts.ReadLine() 'skip the next line if GVRP or GMRP
						End If
						strLine = ts.ReadLine()						' Skip the description
						strLine = ts.ReadLine()
					ElseIf StrComp(Mid(strLine, 1, 10), "VLAN Name=", vbTextCompare) = 0 Then
						Teams(totalTeams, i, 0) = "VLAN"				'Set up keyword for searching VLAN later
						numTVLANS = numTVLANS + 1
						Teams(totalTeams, 0, 2) = numTVLANS
						Teams(totalTeams, i+1, 0) = Mid(strLine, 11)	'VLAN Name
						strLine = ts.ReadLine()
						Teams(totalTeams, i+2, 0) = Mid(strLine, 9)	'VLAN ID												
						i = i + 3
						strLine = ts.ReadLine()
					End If   
				Loop				
				totalTeams = totalTeams + 1
			ElseIf (StrComp(Mid(strLine, 1,17), "OEMCustomizeable=", vbTextCompare) = 0) Then
				strOEMCustomizeableValue = Mid(strLine, 18)
			ElseIf (StrComp(Mid(strLine, 1,3), "OS=", vbTextCompare) = 0) Then
				strOS = Mid(strLine, 4)
			End If
		Loop 'Until ts.AtEndOfStream
		ts.Close
	End If

	dim teamCount, vlanIndex, vlanCount
	dim teamVlanCount : teamVlanCount = 0

	if numTVLANS > 1 then
		for teamCount = 0 to totalTeams - 1
			teamVlanCount = 0
			for vlanIndex = 0 to 999
				if Teams(teamCount, vlanIndex, 0) = "VLAN" then
					teamVlanCount = teamVlanCount + 1
					vlanCount = vlanIndex
					if Teams(teamCount, vlanCount+2,0) = 0 AND teamVlanCount = 1 then
						dim swapName, swapId
						swapName = Teams(teamCount, vlanCount+1,0)
						swapId = Teams(teamCount, vlanCount+2,0)
						Teams(teamCount, vlanCount+1,0) = Teams(teamCount, vlanCount+3+1,0)
						Teams(teamCount, vlanCount+2,0) = Teams(teamCount, vlanCount+3+2,0) 
						Teams(teamCount, vlanCount+3+1,0) = swapName
						Teams(teamCount, vlanCount+3+2,0) = swapId
						bNewTeam = 0
						exit for
					end if	
				end if
			next
		next
	end if

End Sub

'=================================================================================================
'
' Sub ValidateAdapters()
' Check for installed adapter count, check against settings sets and get user input for mismatches.
' Sets strInput and strChoices
'
'=================================================================================================
Sub ValidateAdapters()
	Dim ii, iii, counter
	Dim strTemp, strTeamTemp, strCaptions, bFound
	Dim Capability
	Dim SplitID,SysAdapterID,FileAdapterID
	Dim bIsLADIntelDevice
	
	bUserInput = FALSE
	existTotalAdapters = 0
	iii = 0
	'Count existing adapters and assign captions to array for user selection
	For Each AdapterObj In AdapterSets
		bIsLADIntelDevice = false

		IsIntelDevice AdapterObj, bIsLADIntelDevice

		'Knock out Non-Intel and disabled adapters
            	if(bIsLADIntelDevice and AdapterObj.StatusInfo = 3) then		
			    ReDim Preserve Captions(iii + 1)
			    existTotalAdapters = existTotalAdapters + 1
			    Captions(iii) = AdapterObj.Caption
			    iii = iii + 1				
		End if		
	Next

	'For BusDeviceFunction restores check that there are matches
	If bBdfRestore = TRUE then
		For index = 0 to existTotalAdapters - 1
                        bFound = FALSE
			For Each AdapterObj In AdapterSets
				'Compare only the first three parts of the deviceID (excludes the rev)
				'Get all the parts in an array split by &
				SplitID = Split(AdapterObj.PCIDeviceID,"&")
				'Re-initialize SplitID saving only the first three (saving array elements 0-2)
				ReDim Preserve SplitID(2)
				'concatinate the three parts back together with & back in the middle
				SysAdapterID = Join(SplitID,"&")
				'Do the same for the file device ID
				SplitID = Split(Adapters(index, 1, 1),"&")
				ReDim Preserve SplitID(2)
				FileAdapterID = Join(SplitID,"&")

				If ((StrComp(AdapterObj.SlotID, Adapters(index, 4, 0)) = 0) AND (StrComp(SysAdapterID, FileAdapterID) = 0)) Then			'Adapter BusFunctionID
					bFound = TRUE
				End If
			Next
			If bFound = TRUE Then
				Adapters(index, 0, 0) = TRUE  'Adapter existence flag
			Else
				WScript.Echo "Invalid device found. Please verify configuration file matches your system configuration."
				Adapters(index, 0, 0) = FALSE
			End If
		Next
	Else
		'Check existing adapters against settings sets and set bFound value accordingly
		For index = 0 to existTotalAdapters - 1
			bFound = FALSE
			For Each AdapterObj In AdapterSets
				If StrComp(AdapterObj.Caption, Adapters(index, 1, 0)) = 0 Then	'Adapter's Name
					bFound = True
				Elseif (bIsUpgrade = True) AND (StrComp(AdapterObj.PermanentAddress, Adapters(index, 1, 1)) = 0) AND (AdapterObj.PermanentAddress <> "") Then	'Adapter's PermanentAddress
					bFound = True
				Elseif (bIsUpgrade = False) AND (StrComp(AdapterObj.PCIDeviceID, Adapters(index, 1, 1)) = 0) AND (AdapterObj.PCIDeviceID <> "") Then			'Adapter's PCIDeviceID
					bFound = True
				End If
			Next
			If bFound = TRUE Then
				Adapters(index, 0, 0) = TRUE  'Adapter existence flag
			Else
				Adapters(index, 0, 0) = FALSE
			End If
		Next
	End If


	'Set string of adapter settings captions for user selection
	For ii = 0 to (totalAdapters - 1) 
		If Adapters(ii, 1, 0) <> "" Then
			strTemp = strTemp & Adapters(ii, 3, 0) & ". " & Adapters(ii, 1, 0) & (Chr(10) & Chr(13)) & "    Priv Desc:  " & arrPrivDesc(ii) & (Chr(10) & Chr(13))
			'<SettingsIndex> + ". " + <AdapterName> + 
			'Newline + 
			'Return + "Priv Desc:  " + <PrivateDesc> + 
			'Newline + 
			'Return
		End If
	Next
	'Set string of team descriptions for user selection
	For ii = 0 to (totalTeams - 1) 
		If Teams(ii, 0, 0) <> "" Then
			strTeamTemp = strTeamTemp & Teams(ii, 1, 2) & "." & Teams(ii, 0, 0) & (Chr(10) & Chr(13))
			counter = counter + 1
		End If
	Next

	'Set string of installed adapter captions for user selection
	For ii = 0 to Ubound(Captions)
		If Captions(ii) <> "" Then
			strCaptions = strCaptions & Captions(ii) & (Chr(10) & Chr(13))
		End If
	Next

	'Checking number of installed adapters vs. settings list, prompt user if the numbers don't match"
	bMisMatch = FALSE

'	If existTotalAdapters < (totalAdapters) Then
'		bMisMatch = TRUE
'		strInput = InputBox("There are " & existTotalAdapters & " installed adapters and " & totalAdapters & " adapter configuration sets contained in " & strFname & "."  & (Chr(10) & Chr(13)) & (Chr(10) & Chr(13)) & "Installed Adapters:  " & (Chr(10) & Chr(13)) & strCaptions & (Chr(10) & Chr(13)) & "Enter selections separated by commas, no spaces or periods."  & (Chr(10) & Chr(13)) &  "Adapter Sets-" & (Chr(10) & Chr(13)) & strTemp & (Chr(10) & Chr(13)) & "Team Sets-  " & (Chr(10) & Chr(13)) & strTeamTemp, "Mismatched Settings Sets")
'		If strInput <> "" Then
'			bUserInput = TRUE
'			ValidateInput strInput
'			
'		Else
'			strInput = InputBox("ERROR:  No Selection Entered!" & (Chr(10) & Chr(13)) & "User-defined descriptions are listed below.  Enter selections to apply, enter numbers separated by commas, no spaces or periods." & (Chr(10) & Chr(13)) & (Chr(10) & Chr(13)) & strTemp & (Chr(10) & Chr(13)) & strTeamTemp, "Enter Selection")
'			If strInput = "" Then
'				WScript.Echo "Script cannot continue without user selection."
'				bUserInput = FALSE
'				Exit Sub
'			Else
'				bUserInput = TRUE
'				ValidateInput strInput
'			End If
'		End If
'	ElseIf existTotalAdapters > totalAdapters Then		
'		bMisMatch = TRUE
'		WScript.Echo "There are not enough settings sets to apply to installed adapters.  Resave or check settings file."
'		bUserInput=FALSE
'		Exit Sub
'	End If
End Sub

'=================================================================================================
'
' Sub CheckSelected(ByVal strSettingsIndex)
' Check whether current settings set was selected by any user input, defaults to true if no mismatch
' Sets bSelected to True or False
'
'=================================================================================================
Sub CheckSelected(ByVal strSettingsIndex)
	bSelected = FALSE
	Dim iv, v, b
	If strChoices <> "" Then
		v = InStr(1, strChoices, ",", vbTextCompare)
		If v > 0 Then 
			iv = InStr(1, strChoices, strSettingsIndex, vbTextCompare)
			If iv > 0 Then
				bSelected = TRUE
			End If
		ElseIf (strChoices = strSettingsIndex) Then
				bSelected = TRUE
		End If
	ElseIf bMisMatch = FALSE Then
		bSelected = TRUE
	End If
End Sub

'==================================================================================================
'
' ApplyAdapterSettings(strSettingsIndex)
' Apply selected or all adapter settings and return status message to user
' 
'==================================================================================================
Sub ApplyAdapterSettings(ByVal strSettingsIndex)
	Dim IANet_configur, IANet_Obj, IANetSettingObj
	Dim IANet_802dot1VLANService, IANet_802dot1VLANObj
	Dim IANet_VLANconfigur, IANet_VLANObj, InParameterObj, OutParameterObj
	Dim TempVlanObject, VlanObjectSet,VlanObject, IANet_VLANConfObj,IANet_VLANSet
	Dim strSettingValue,bFoundPossibleValue,bVLAN 
	Dim strVLANName, strVLANID, FinalVlanObject
	Dim strQuery, strExistAdapterName, strExist
	Dim Dumbpath, i, ii, iii, iv, z, b, k, x, cstrPath, pos, intCurCount
	Dim TargetObjInstance, TargetObj, numVLANS,InParameter
	Const wbemFlagUseAmendedQualifiers = &h20000
	Const Temp = TRUE
	dim bAlreadyWarned' Used to tell the user that ANS might not be installed
	dim savedJValue : savedJValue = -1
	dim alreadyRestored
	
	bAlreadyWarned = false 
	Set Dumbpath = CreateObject("WbemScripting.SWbemObjectPath")
	'Setting applied flag to 0
	Adapters(index, 0, 1) = 0

	On Error Resume Next
	'Updating Adapter's settings by checking if selected and if not already applied
	strExistAdapterName = AdapterObj.Caption
	If (Adapters(index, 3, 0) = strSettingsIndex) Then
		WScript.Echo "Applying setting set " & strSettingsIndex & " to " & AdapterObj.Caption 
		If Adapters(index, 0, 0) Then	' Check if this adapter exists from previous validation sequence (Adapter Existence flag)
			strAdapterName = Adapters(index, 1, 0)			' Get Adapter's Name from this settings set 
			strSettingsIndex = Trim(strSettingsIndex)
		
			Adapters(index, 0, 1) = 1  ' Flag for setting being applied
			
			SValueSet.Add "GET_EXTENSIONS", true
      			SValueSet.Add "GET_EXT_KEYS_ONLY", false
			SValueSet.Add "IANet_PartialData", 512
  
			strQuery = "ASSOCIATORS OF {" & AdapterObj.Path_.Path & "} WHERE ResultClass = IANet_AdapterSetting"
			Set IANet_configur = wbemServices.ExecQuery(strQuery,,,SValueSet)			
							
				Dim j
				For j = SETTINGS_INDEX to maxSettings-1
					If StrComp(Adapters(index, j, 0), "", vbTextCompare) = 0 then   'Adapter setting Name
						Exit For						
						
					ElseIf bVLAN AND bNoAns <> true Then
						For x = 0 to numVLANS - 1
							if numVlans = 1 AND Adapters(index, j+1, 0) = 0 then
								wscript.echo "Unable to create an Untagged VLAN without a Tagged VLAN"								
								exit for
							end if

							if x = 0 AND Adapters(index, j+1, 0) = 0 then
								savedJValue = j
								wscript.echo "Untagged VLAN is first VLAN in the list, saving the index.  This VLAN will be restored last."
							end if
							
							Set TempVlanObject = wbemServices.Get("IANet_802dot1QVLANService", ,SValueSet)
							Set InParameterObj = TempVlanObject.Methods_.Item("CreateVLAN").InParameters.SpawnInstance_()
							InParameterObj.Name = Adapters(index, j, 0)						
							InParameterObj.VLANNumber = Adapters(index, j+1, 0)						
							strQuery = "ASSOCIATORS OF {" & AdapterObj.Path_.Path & "} WHERE ResultClass = IANet_802dot1QVLANService"
							Set VlanObjectSet = wbemServices.ExecQuery(strQuery,,,SValueSet)
							
							For Each VlanObject In VlanObjectSet
								Set FinalVlanObject = wbemServices.Get(VlanObject.Path_.Path, ,SValueSet)					
								Set OutParameterObj = FinalVlanObject.ExecMethod_("CreateVLAN", InParameterObj, 0, SValueSet)
								bModified = TRUE
								Exit For
							Next
							
							ExecApply wbemServices, strNetSerObjPath, SessionObject
						
							CreateSessions()
						
							if NOT (x = 0 AND Adapters(index, j+1, 0) = 0) then
								WSCript.Echo "updating VLAN:" & Adapters(index, j, 0) & " settings..."
							end if
							For k = j+2 to maxSettings-1
								If StrComp(Adapters(index, k, 0), "", vbTextCompare) = 0 then
									Exit For		
								ElseIf Adapters(index, k, 0) = "VLAN" Then
									Exit For
								Else
									strQuery = "ASSOCIATORS OF {" & AdapterObj.Path_.Path & "}WHERE ResultClass = IANet_802dot1QVLANService"
									Set IANet_802dot1VLANService = wbemServices.ExecQuery(strQuery,,,SValueSet)
									If IANet_802dot1VLANService.Count <> 0 Then 
										For Each IANet_802dot1VLANObj In IANet_802dot1VLANService
											strQuery = "ASSOCIATORS OF {" & IANet_802dot1VLANObj.Path_.Path & "}WHERE ResultClass = IANet_VLAN"
											Set IANet_VLANSet = wbemServices.ExecQuery(strQuery,,,SValueSet)
											For Each IANet_VLANObj In IANet_VLANSet
												If StrComp(IANet_VLANObj.VLANName, Adapters(index, j, 0), vbTextCompare) = 0 Then
												
												strQuery = "ASSOCIATORS OF {" & IANet_VLANObj.Path_.Path & "} WHERE ResultClass = IANet_VLANSetting" 
														Set IANet_VLANconfigur = wbemServices.ExecQuery(strQuery,,,SValueSet)
													For Each IANet_VLANConfObj In IANet_VLANconfigur
														If StrComp(IANet_VLANConfObj.Caption, Adapters(index, k, 0), vbTextCompare) = 0 Then
															If StrComp(IANet_VLANConfObj.CurrentValue, Adapters(index, k, 1), vbTextCompare) <> 0 Then
																IANet_VLANConfObj.CurrentValue = Adapters(index, k, 1)
																Set Dumbpath = IANet_VLANConfObj.Put_ (wbemFlagUseAmendedQualifiers, SValueSet) 
																bModified = True
																Exit For				
															End If
														End If
													Next
												End If
											Next
										Next
									End If
								End If
							Next
							
							if savedJValue >= 0 AND x = numVLANS - 1 AND alreadyRestored <> true then
								j = savedJValue
								x = x - 1
								alreadyRestored = true
							else
								j = k + 1
							end if
							
						Next
						bVLAN = False
					ElseIf StrComp(Adapters(index, j, 0), "VLAN", vbTextCompare) = 0 Then
						bVLAN = True
						numVLANS = Adapters(index, 0, 2)
					ElseIf StrComp(Adapters(index, j, 0), "", vbTextCompare) <> 0 Then
					    For Each IANet_Obj In IANet_configur					    	   
						   If StrComp(Adapters(index, j, 0), IANet_Obj.Caption, vbTextCompare) = 0 Then													
								If (StrComp(Adapters(index, j, 1), IANet_Obj.CurrentValue, vbTextCompare) <> 0) OR (StrComp(IANet_Obj.Caption, "PerformanceProfile", vbTextCompare) = 0) Then
									'Set IANetSettingObj = wbemServices.Get(IANet_Obj.Path_.Path, ,SValueSet)
									If StrComp(IANet_Obj.Path_.Class, "IANet_AdapterSettingEnum", vbTextCompare) = 0 Then						
										
										'Get the most current PerformanceProfile to avoid passing down different display value and current values. HSD 5107226
										if (StrComp(IANet_Obj.Caption, "PerformanceProfile", vbTextCompare) = 0) Then
											Set IANet_Obj = wbemServices.Get(IANet_Obj.Path_.Path, ,SValueSet)
										end if										

										IANet_Obj.CurrentValue = Adapters(index, j, 1)
										Set Dumbpath = IANet_Obj.Put_(wbemFlagUseAmendedQualifiers, SValueSet)
										bModified = True	
	
									Else
										if StrComp(Adapters(index,j,0), "LLIPORTS", vbTextCompare) = 0 then
											dim LLIPortsArray
											
											LLIPortsArray = ConvertStringToStringArray(Adapters(index,j,1), ",")
											IANet_Obj.CurrentValues = LLIPortsArray
										else
											IANet_Obj.CurrentValue = Adapters(index, j, 1)	
										end if

										Set Dumbpath = IANet_Obj.Put_(wbemFlagUseAmendedQualifiers,SValueSet)'(wbemChangeFlagUpdateOnly, SValueSet)																
										bModified = True
										Exit For
									End If			
								End If								
							End If
						Next			
					End If
				Next	
		End If 	
	End If 
End Sub

'=================================================================================================
'
' ApplyTeamSettings(ByVal strSettingsIndex)
' Apply selected settings and return status to user
'
'=================================================================================================
Sub ApplyTeamSettings(ByVal strSettingsIndex)
	Dim TargetObjInstance 
	Dim bTeam, i, j, k, x, intCurCount, TeamAdapObj, TeamAdapObjSet, FinalVlanObject
	Dim IANet_configur, IANet_Obj, IANetSettingObj, TeamsObjSet, cstrPath,temObj
	Dim IANet_802dot1VLANService, IANet_802dot1VLANObj, TeamObjSet1, pos
	Dim IANet_VLANconfigur, IANet_VLANObj, Dumbpath, bTest, VLANObjectSet
	Dim VLANObjSet, VLANObj, b, a, TempVlanObject, InParameterObj, VlanObject
	Dim PartComponentString, GroupComponentString, TargetObj, TeamObj
	Dim TeamObj1, TeamsSet, TeamDeviceId, OutParameterObj, bFoundPossibleValue
	Dim strCapabilities, intTest, arrCaps, strQuery, bVLAN, numTVLANS
	Dim p, r,IANet_Virtualconfigur,temp,jj,adapterCount
	'For GVRP settings restore for Vlans
	Dim IANet_VlanIns,IANet_VlanObject,IANet_VLANSettingIns,IANet_VLANSettingObj
	Const wbemFlagUseAmendedQualifiers = &h20000
	bModified = False

	' for setting preferred primary
	Dim oTeamedMemberAdapters,oTeamedMemberAdaptersSet
	Dim AdapterInTeamOffset: AdapterInTeamOffset = 0
	Dim VlanName
	Dim foundMatch
	Dim SplitID,SysAdapterID,FileAdapterID
	On Error Resume Next
	
	p=0
	r=2		
	i=5

	CreateSessions() 'SCR 37163
	
	Redim Preserve AdapterPath(1)
	
	If Teams(index, 1, 2) = strSettingsIndex Then	
		bTeam = TRUE
		WScript.Echo "Creating Team: " & Teams(index, 0, 0) & "..."

		if (IsTeamSupportedInCurrentOS(Teams(index,1,0)) <> TRUE) then
			wscript.echo "Unable to create team. Team type not supported in this version of the OS."
			ExecApply wbemServices, strNetSerObjPath, SessionObject	' Without this before exiting, the script hangs/fails 
			exit sub
		end if

		'  Check to see that the team type is not GEC
		'  GEC are now to be created as an SLA team
		if ((Teams(index,1,0) = GEC_TEAM_TYPE)) then
			wscript.echo "Converting GEC to SLA"
			Teams(index,1,0) = SLA_TEAM_TYPE
		end if
		
		Set TeamsSet = wbemServices.Get("IANet_TeamOfAdapters",,SValueSet)
		Set InParameterObj = TeamsSet.Methods_.Item("CreateTeam").InParameters.SpawnInstance_()
		adapterCount = Teams(index, 1, 1)
		
		Redim Preserve AdapterPath(adapterCount)

        For r=2 to Teams(index, 1, 1)+1
            foundMatch = false

            If bBdfRestore = TRUE then
                For Each AdapterObj In AdapterSets 
                    'Compare only the first three parts of the deviceID (excludes the rev)
                    'Get all the parts in an array split by &
                    SplitID = Split(AdapterObj.PCIDeviceID,"&")
                    'Re-initialize SplitID saving only the first three (saving array elements 0-2)
                    ReDim Preserve SplitID(2)
                    'concatinate the three parts back together with & back in the middle
                    SysAdapterID = Join(SplitID,"&")
                    'Do the same for the file device id
                    SplitID = Split(Teams(index, r, 5),"&")
                    ReDim Preserve SplitID(2)
                    FileAdapterID = Join(SplitID,"&")
                    
                    If ((StrComp(AdapterObj.SlotID, Teams(index, r, 6)) = 0) AND (StrComp(SysAdapterID, FileAdapterID) = 0)) Then
                        foundMatch = true
                        AdapterPath(p) = AdapterObj.Path_.Path
                        p=p+1
                        exit for
                    End if
                Next
            Else
                For Each AdapterObj In AdapterSets 
                    If AdapterObj.Caption = Teams(index, r, 1) then 						
                        foundMatch = true
                        AdapterPath(p) = AdapterObj.Path_.Path
                        p=p+1
                        exit for
                    Elseif (bIsUpgrade = True) AND (AdapterObj.PermanentAddress = Teams(index, r, 5)) AND (AdapterObj.PermanentAddress <> "") then
                        foundMatch = true
                        AdapterPath(p) = AdapterObj.Path_.Path
                        p=p+1
                        exit for
                    Elseif (bIsUpgrade = False) AND (AdapterObj.PCIDeviceID = Teams(index, r, 5)) AND (AdapterObj.PCIDeviceID <> "") then
                        foundMatch = true
                        AdapterPath(p) = AdapterObj.Path_.Path
                        p=p+1
                        exit for
                    End if
                Next
            End If

            if(foundMatch = false) Then
                WScript.Echo "Invalid device found. Please verify configuration file matches your system configuration."
                ExecApply wbemServices, strNetSerObjPath, SessionObject	' Without this before exiting, the script hangs/fails 
                exit sub
            End if
        Next

		Redim Preserve AdapterPath(p-1)
		InParameterObj.Properties_.Item("Adapters") = AdapterPath		
		InParameterObj.TeamingMode = Teams(index, 1, 0)			
		InParameterObj.TeamName    = Teams(index, 0, 0)		
		InParameterObj.MFOEnable   = Teams(index, 1, 3)	

		Dim TempTeam
		TempTeam = InParameterObj.TeamName 
		Set OutParameterObj = TeamsSet.ExecMethod_("CreateTeam", InParameterObj, 0, SValueSet)		
		
		If Err <> 0 Then
			WScript.Echo "Adding Adapter Failed..."
			ErrorCheck()
			'If blTenGigFETeamError Then
			'	SetTenGigFERegKey()
			'End If	
		
		Else
			WScript.Echo "Create Team Success!!!"
			bNewTeam = True
		End If
		
		ExecApply wbemServices, strNetSerObjPath, SessionObject	'SCR 37163
		
		CreateSessions() 'SCR 37163
		
		Set oTeamedMemberAdaptersSet = wbemServices.InstancesOf("IANet_TeamedMemberAdapter",,SValueSet)
		If (IsNull(oTeamedMemberAdaptersSet) = FALSE) Then
			' first we have to find which adapter is the primary and set that one first!!
			For AdapterInTeamOffset = 0 to adapterCount-1 Step 1
				If( TeamedMemberAdapterPreferredPrimarySetting(index, AdapterInTeamOffset) = 1) Then	
					For each oTeamedMemberAdapters in oTeamedMemberAdaptersSet
						If(InStr(oTeamedMemberAdapters.PartComponent,TeamedMemberAdapterPartComponentSetting(index, AdapterInTeamOffset))) Then					
							oTeamedMemberAdapters.AdapterFunction = CStr(TeamedMemberAdapterPreferredPrimarySetting(index, AdapterInTeamOffset))
							oTeamedMemberAdapters.Put_  wbemFlagAmendedUpdateOnly, SValueSet				
							Exit For
						End If
					Next
					Exit For
				End If
			Next
			
			For each oTeamedMemberAdapters in oTeamedMemberAdaptersSet
				For AdapterInTeamOffset = 0 to adapterCount-1 Step 1
					If(InStr(oTeamedMemberAdapters.PartComponent,TeamedMemberAdapterPartComponentSetting(index, AdapterInTeamOffset))) Then
						If (TeamedMemberAdapterPreferredPrimarySetting(index, AdapterInTeamOffset) > 0) Then
							oTeamedMemberAdapters.AdapterFunction = CStr(TeamedMemberAdapterPreferredPrimarySetting(index, AdapterInTeamOffset))
							oTeamedMemberAdapters.Put_  wbemFlagAmendedUpdateOnly, SValueSet									
							Exit For
						End If
					End If
				Next
			Next
		End If

		ExecApply wbemServices, strNetSerObjPath, SessionObject
		
		CreateSessions()
		
		WScript.Sleep(2000)
		
		WScript.Echo "Applying Team Settings to " & TempTeam	

		Set virtualAdapterSets = wbemServices.InstancesOf("IANet_LogicalEthernetAdapter",,SValueSet) 
		For each virtualAdapterObj in virtualAdapterSets
			if StrComp(TempTeam,Mid(virtualAdapterObj.Caption,8), vbTextCompare) = 0 Then				
				strQuery = "ASSOCIATORS OF {" & virtualAdapterObj.Path_.Path & "} WHERE ResultClass = IANet_TeamSetting"
				Set IANet_Virtualconfigur = wbemServices.ExecQuery(strQuery,,,SValueSet)
				TeamDeviceId = virtualAdapterObj.DeviceID			
				
				bVLAN = False
				numTVLANS = Teams(index, 0, 2)	

				Dim bApplySetting: bApplySetting = false
        
				For j = SETTINGS_INDEX to maxSettings-1
					If StrComp(Teams(index, j, 0), "", vbTextCompare) = 0 Then			
						Exit For	
					ElseIf bVLAN Then			
						Set TempVlanObject = wbemServices.Get("IANet_802dot1QVLANService",,SValueSet)
						Set InParameterObj = TempVlanObject.Methods_.Item("CreateVLAN").InParameters.SpawnInstance_()
						InParameterObj.Name = Teams(index, j, 0)
						VlanName = Teams(index, j, 0)
						InParameterObj.VLANNumber = Teams(index, j+1, 0)								

						bVLAN = false
						
						If numTVLANS = 1 And Teams(index, j+1, 0) = 0 Then
							wscript.echo "Unable to create an Untagged VLAN without a Tagged VLAN on this Team"								
							Exit For
						End If
						
						j = j + 1
						Set VlanObjectSet = wbemServices.InstancesOf("IANet_802dot1QVLANService", , SValueSet)
						For Each VlanObject In VlanObjectSet								
							If TeamDeviceId = VlanObject.Name Then															
								Set FinalVlanObject = wbemServices.Get(VlanObject.Path_.Path, ,SValueSet)
								Set OutParameterObj = FinalVlanObject.ExecMethod_("CreateVLAN", InParameterObj, 0, SValueSet)																		
								Exit For
							Else 
								Exit For										
							End If
						Next
						
						ExecApply wbemServices, strNetSerObjPath, SessionObject
						
						CreateSessions()

						WSCript.Echo "updating VLAN:" & Teams(index, j-1, 0) & " settings..."																		

						For k = j+1 to maxSettings-1
							If StrComp(Teams(index, k, 0), "", vbTextCompare) = 0 then
								Exit For		
							ElseIf Teams(index, k, 0) = "VLAN" Then
								Exit For
							ElseIf StrComp(Teams(index, k, 0), "", vbTextCompare) <> 0 Then
								j = k		
								Set IANet_VlanIns = wbemServices.InstancesOf("IANet_Vlan",0,SValueSet) 
								For Each IANet_VlanObject in IANet_VlanIns													
									If IANet_VlanObject.ParentID = TeamDeviceId then
										If IANet_VlanObject.VLANName = VlanName then
										strQuery = "ASSOCIATORS OF {" & IANet_VlanObject.Path_.Path & "}WHERE ResultClass = IANet_VLANSetting"
										Set IANet_VLANSettingIns = wbemServices.ExecQuery(strQuery,,,SValueSet)								
										For each IANet_VLANSettingObj in IANet_VLANSettingIns                     
											If StrComp(IANet_VLANSettingObj.Caption,Teams(index, k, 0), vbTextCompare) = 0 Then
												If StrComp(IANet_VLANSettingObj.CurrentValue, Teams(index, k, 1), vbTextCompare) <> 0 Then																																													
													IANet_VLANSettingObj.CurrentValue = Teams(index, k, 1)
													Set Dumbpath = IANet_VLANSettingObj.Put_ (wbemFlagUseAmendedQualifiers, SValueSet) 
													bApplySetting = true																
													Exit For
												End If										
											End If										
											Next																	
										End If
									End If								
								Next					
							End If														
						Next 					
						
					ElseIf StrComp(Teams(index, j, 0), "VLAN", vbTextCompare) = 0 Then
						bVLAN = True					
					ElseIf StrComp(Teams(index, j, 0), "", vbTextCompare) <> 0 Then		
					' Updating Team's Settings
						For Each IANet_Obj In IANet_Virtualconfigur
						  If StrComp(TeamDeviceId, IANet_Obj.ParentId, vbTextCompare) =0 Then
							If StrComp(Teams(index, j, 0), IANet_Obj.Caption, vbTextCompare) = 0 Then
								If StrComp(Teams(index, j, 1), IANet_Obj.CurrentValue, vbTextCompare) <> 0 Then
									If StrComp(IANet_Obj.Path_.Class, "IANet_TeamSettingEnum", vbTextCompare) = 0 Then
										bFoundPossibleValue = False
										For I = 0 To UBound(IANet_Obj.PossibleValues)
											If StrComp(IANet_Obj.PossibleValues(I), Teams(index, j, 1), vbTextCompare) = 0 Then
												IANet_Obj.CurrentValue = IANet_Obj.PossibleValues(I)
												Set Dumbpath = IANet_Obj.Put_(wbemFlagUseAmendedQualifiers, SValueSet)
												bApplySetting = true
												bModified = True
												bFoundPossibleValue = True
												Exit For
											End If
										Next
										If bFoundPossibleValue = False Then
											WScript.Echo "Can't apply the new '" & Teams(index, j, 0) & "' setting value of " & Teams(index, j, 1) & "' because the new value is not in the possible value range."
										End If
									Else
										IANet_Obj.CurrentValue = Teams(index, j, 1)
										Set Dumbpath = IANet_Obj.Put_ (wbemFlagUseAmendedQualifiers, SValueSet)
										bApplySetting = true							
										bModified = True
										Exit For
									End If			
								End If				
							End If
						  End if
						Next
					
					End If
					If bApplySetting Then
						ExecApply wbemServices, strNetSerObjPath, SessionObject	
						CreateSessions()
						bApplySetting = false
					End If 
				Next
			End if
		Next		
	End if
	ExecApply wbemServices, strNetSerObjPath, SessionObject	'SCR 37163
End Sub
'======================================================================================================

'Sub SetTenGigFERegKey()
	'Write a value to the Registry that Team Creation Failed because we found a 10/100 and 10 gig Team	
'	Dim oReg, strKeyPath,strValueName,strValue
'	Set oReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
'	strKeyPath ="SOFTWARE\INTEL\NIC\Team_FE_10Gig"
'	strValueName = "10Gig_FE_Team"
'	strValue = 1
'	WScript.Echo "Setting the Registry Value"
'	oReg.SetDWORDValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue	
	

'End Sub
'======================================================================================================
'
' Sub ErrorCheck()
' Displays Error and Extended Error Info to standard output
'
'======================================================================================================
Sub ErrorCheck()
	Dim errExObject, strErrText
	WScript.Echo "Error Number=" & Err.Number
	WScript.Echo "Error Description=" & Err.Description
	Set errExObject = CreateObject("WbemScripting.SWbemLastError")
	If IsNull(errExObject) = FALSE Then
		strErrText = errExObject.GetObjectText_
		WScript.Echo "MOF=" & strErrText
		'If(InStr(1,strErrText, "StatusCode = 10000;", 1) <> 0) then
		'	blTenGigFETeamError = true							
		'End If
	End If
End Sub
'======================================================================================================

'*****************************************************************************************
'*****************************************************************************************
'=======================================================================================
'
' Sub:  Remove()
'	Removes teams and VLANs from the system
'  
'=======================================================================================

Sub Remove()
	Dim regAccess	
	
	CreateSessions()
	Set VLANObjSet = wbemServices.InstancesOf("IANet_VLAN",,SValueSet)
	
	' SCR 50668 Fix:  Without ANS installed, the IANet_VLAN class
	' Is not exposed in the WMI, causing the for each loop below to fail.  Since 
	' isNull() and isEmpty() are not reflecting when IANet_VLAN
	' is not there, it was needed to be done like this.  
	
	' Turn on error handling (script does not halt on errors)
	On Error Resume Next
		For Each VLANObj In VLANObjSet				
			' Check if there was an error accessing the VLANs collection
			' if not, save the ANS information
			if err.number = 0 then
				bHasTeamOrVLAN = TRUE 
				WScript.Echo "Removing any existing VLAN's..."
				VLANObj.Delete_ 0, SValueSet
				If Err.Number = -1879109552 Then
					WScript.Echo "Found Hyper-V bound VLAN"
					
					set regAccess = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv") 
					regAccess.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Intel\Network_Services\DMIX","RemoveTeams",0
					
					Exit For
				End If
			end if
		Next 
	' Turn off error handling (script halts on errors again)
	On Error Goto 0

	ExecApply wbemServices, strNetSerObjPath, SessionObject	

	CreateSessions()

	Set TeamsObjSet = wbemServices.InstancesOf("IANet_TeamOfAdapters",,SValueSet)

	' SCR 50668 Fix:  Without ANS installed, the IANet_TeamOfAdapters class
	' Is not exposed in the WMI, causing the for each loop below to fail.  Since 
	' isNull() and isEmpty() are not reflecting when IANet_TeamOfAdapters
	' is not there, it was needed to be done like this.  
	
	' Turn on error handling (script does not halt on errors)
	On Error Resume Next
		For Each TeamObj In TeamsObjSet		
			' Check if there was an error accessing the Team of Adapter collection
			' if not, save the ANS information
			if err.number = 0 then
				WScript.Echo "Removing any existing Teams..."
				bHasTeamOrVLAN = True		
				TeamObj.Delete_ 0, SValueSet
				If Err.Number = -1879109580 Then
					WScript.Echo "Found Hyper-V bound team"
					
					set regAccess = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv") 
					regAccess.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Intel\Network_Services\DMIX","RemoveTeams",0
					
					Exit For
				End If
			end if
		Next
	On Error Goto 0
	
	ExecApply wbemServices, strNetSerObjPath, SessionObject
End Sub

'****************************************************************************

'=====================================================================================
'
' Sub:	RestoreWINSSettings(ByVal strInputFname)'
'   
'=====================================================================================

Sub RestoreWINSSettings(ByVal strInputFname)
	Dim fso
	Dim wbemServices_local
	Dim TeamSets,TeamObj,VLANSets,VlanObj,AdatperSets_local,AdatperObj_local
	Dim ts, strLine
	Dim NameServerList(),NetBiosOption,TeamName,VlanName,AdapterName
	Dim gIndex
	Dim ResetSettings

	Set wbemServices_local = GetObject("winmgmts:{impersonationLevel=impersonate}//./root/IntelNcs2")		
	
	Set fso = CreateObject("Scripting.FileSystemObject")
	
	If fso.FileExists (strInputFname) <> True Then
		Wscript.Echo "The file " & strInputFname
		Wscript.Echo "could not be found."
		Wscript.Echo "Either the file or the directory has been deleted "
		WScript.Echo "or Restore is being run on a cloned system."
		WScript.Echo "Unable to restore Static IP Addresses."	
		bError = TRUE
		Exit Sub
	Else	
		Set ts = fso.OpenTextFile(strInputFname, 1)
		
		ReDim Preserve NameServerList(-1)
		NetBiosOption = ""
			
		Do Until ts.AtEndOfStream		
            'Initialize ServerList to be empty
            gIndex = -1
		    Redim NameServerList(-1)
            gIndex = gIndex + 1
            ReDim Preserve NameServerList(gIndex)
            NameServerList(gIndex) = ""

            'start to read for settings
			strLine = ts.ReadLine()
			If StrComp(strLine,"Team", vbTextCompare) = 0 Then			
				strLine = ts.ReadLine()
				'Store Team Name
				TeamName = Mid(strLine,11)								
				strLine = ts.ReadLine()				
				If ((StrComp(strLine,"NAMESERVERLIST", vbTextCompare) = 0) OR (StrComp(strLine,"NETBIOSOPTIONS", vbTextCompare) = 0)) Then
					'Store NameServerList
                    If StrComp(strLine,"NAMESERVERLIST", vbTextCompare) = 0 Then
					    gIndex = -1
					    Redim NameServerList(-1)
					    strLine = ts.ReadLine()
					    Do While (StrComp(strLine,"NETBIOSOPTIONS", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
						    gIndex = gIndex + 1
						    ReDim Preserve NameServerList(gIndex)
						    NameServerList(gIndex) = strLine
						    strLine = ts.ReadLine()
					    Loop
					End If

					'Store NetBiosOptions
					NetBiosOption = ""
					If StrComp(strLine,"NETBIOSOPTIONS", vbTextCompare) = 0 Then
						strLine = ts.ReadLine()
						NetBiosOption = strLine
						strLine = ts.ReadLine()
					End If	
				
					Set TeamSets = wbemServices_local.InstancesOf("IANet_LogicalEthernetAdapter")
					For each TeamObj in TeamSets					
						if (StrComp(Mid(TeamObj.Caption,8),TeamName,VbTextCompare) = 0) then
							SetWMIInfo TeamObj,TEAM_ADAPTER,NameServerList,NetBiosOption				
						End If
					Next
					if(StrComp(strLine,"VLAN", vbTextCompare) = 0) Then					
						Do while StrComp(strLine, "", vbTextCompare) <> 0											
							strLine = ts.ReadLine()
							VlanName = Mid(strLine,11)										
							strLine = ts.ReadLine()	
					        If ((StrComp(strLine,"NAMESERVERLIST", vbTextCompare) = 0) OR (StrComp(strLine,"NETBIOSOPTIONS", vbTextCompare) = 0)) Then
                                If StrComp(strLine,"NAMESERVERLIST", vbTextCompare) = 0 Then
					                'Store NameServerList
					                gIndex = -1
					                Redim NameServerList(-1)
					                strLine = ts.ReadLine()
					                Do While (StrComp(strLine,"NETBIOSOPTIONS", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
						                gIndex = gIndex + 1
						                ReDim Preserve NameServerList(gIndex)
						                NameServerList(gIndex) = strLine
						                strLine = ts.ReadLine()
					                Loop
                                End If
					
					            'Store NetBiosOptions
					            NetBiosOption = ""
					            If StrComp(strLine,"NETBIOSOPTIONS", vbTextCompare) = 0 Then
						            strLine = ts.ReadLine()
						            NetBiosOption = strLine
						            strLine = ts.ReadLine()
					            End If	
									
								Set VLANSets = wbemServices_local.InstancesOf("IANet_VLAN")			
								For each VlanObj in VLANSets												
									If (StrComp(VlanObj.VLANName,VlanName,VbTextCompare) = 0) then
										If (InStr(1,VlanObj.Caption, TeamName, 1) <> 0) then
											SetWMIInfo VlanObj,VLAN_ADAPTER,NameServerList,NetBiosOption				
											exit for
										End if
									End If
								Next
							Else
								'wscript.echo"Nothing to set Vlan-Team"			
								'exit do
							End if						
						Loop					
					End if
				ElseIf(StrComp(strLine,"VLAN", vbTextCompare) = 0) Then	
					Do while StrComp(strLine, "", vbTextCompare) <> 0					
						strLine = ts.ReadLine()
						VlanName = Mid(strLine,11)										
						strLine = ts.ReadLine()	
						If ((StrComp(strLine,"NAMESERVERLIST", vbTextCompare) = 0) OR (StrComp(strLine,"NETBIOSOPTIONS", vbTextCompare) = 0)) Then
                            If StrComp(strLine,"NAMESERVERLIST", vbTextCompare) = 0 Then
					            'Store NameServerList
					            gIndex = -1
					            Redim NameServerList(-1)
					            strLine = ts.ReadLine()
					            Do While (StrComp(strLine,"NETBIOSOPTIONS", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
						            gIndex = gIndex + 1
						            ReDim Preserve NameServerList(gIndex)
						            NameServerList(gIndex) = strLine
						            strLine = ts.ReadLine()
					            Loop
                            End if
					
					        'Store NetBiosOptions
					        NetBiosOption = ""
					        If StrComp(strLine,"NETBIOSOPTIONS", vbTextCompare) = 0 Then
						        strLine = ts.ReadLine()
						        NetBiosOption = strLine
						        strLine = ts.ReadLine()
					        End If	
								
							Set VLANSets = wbemServices_local.InstancesOf("IANet_VLAN")			
							For each VlanObj in VLANSets												
								If (StrComp(VlanObj.VLANName,VlanName,VbTextCompare) = 0) then
									If (InStr(1,VlanObj.Caption, TeamName, 1) <> 0) then
										SetWMIInfo VlanObj,VLAN_ADAPTER,NameServerList,NetBiosOption			
										exit for
									End if
								End If
							Next
						Else
							'wscript.echo"Nothing to set Vlan-Team"										
						End if						
					Loop
				Else 
					'wscript.echo"Nothing to set Team"			
				End if				
			ElseIf(StrComp(Mid(strLine,1,13),"Adapter Name=", vbTextCompare) = 0) Then	
				Do while StrComp(strLine, "", vbTextCompare) <> 0				
					AdapterName = Mid(strLine,14)								
					strLine = ts.ReadLine()
				
					If(StrComp(strLine,"VLAN", vbTextCompare) = 0) Then							
						strLine = ts.ReadLine()
						VlanName = Mid(strLine,11)										
						strLine = ts.ReadLine()	
						If ((StrComp(strLine,"NAMESERVERLIST", vbTextCompare) = 0) OR (StrComp(strLine,"NETBIOSOPTIONS", vbTextCompare) = 0)) Then
                            If StrComp(strLine,"NAMESERVERLIST", vbTextCompare) = 0 Then
					            'Store NameServerList
					            gIndex = -1
					            Redim NameServerList(-1)
					            strLine = ts.ReadLine()
					            Do While (StrComp(strLine,"NETBIOSOPTIONS", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
						            gIndex = gIndex + 1
						            ReDim Preserve NameServerList(gIndex)
						            NameServerList(gIndex) = strLine
						            strLine = ts.ReadLine()
					            Loop
                            End If
					
					        'Store NetBiosOptions
					        NetBiosOption = ""
					        If StrComp(strLine,"NETBIOSOPTIONS", vbTextCompare) = 0 Then
						        strLine = ts.ReadLine()
						        NetBiosOption = strLine
						        strLine = ts.ReadLine()
					        End If	
								
							Set VLANSets = wbemServices_local.InstancesOf("IANet_VLAN")			
							For each VlanObj in VLANSets												
								If (StrComp(VlanObj.VLANName,VlanName,VbTextCompare) = 0) then
									If (InStr(1,VlanObj.Caption, AdapterName, 1) <> 0) then
										SetWMIInfo VlanObj,VLAN_ADAPTER,NameServerList,NetBiosOption
									End if			
								End If
							Next
						Else
							'Wscript.echo"Nothing to set vlan-adapter"										
						End if
					Else
						If ((StrComp(strLine,"NAMESERVERLIST", vbTextCompare) = 0) OR (StrComp(strLine,"NETBIOSOPTIONS", vbTextCompare) = 0)) Then
                            If StrComp(strLine,"NAMESERVERLIST", vbTextCompare) = 0 Then
					            'Store NameServerList
					            gIndex = -1
					            Redim NameServerList(-1)
					            strLine = ts.ReadLine()
					            Do While (StrComp(strLine,"NETBIOSOPTIONS", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
						            gIndex = gIndex + 1
						            ReDim Preserve NameServerList(gIndex)
						            NameServerList(gIndex) = strLine
						            strLine = ts.ReadLine()
					            Loop
                            End If
					
					        'Store NetBiosOptions
					        NetBiosOption = ""
					        If StrComp(strLine,"NETBIOSOPTIONS", vbTextCompare) = 0 Then
						        strLine = ts.ReadLine()
						        NetBiosOption = strLine
						        strLine = ts.ReadLine()
					        End If	
							
							Set AdatperSets_local = wbemServices_local.InstancesOf("IANet_PhysicalEthernetAdapter")
							For each AdatperObj_local In AdatperSets_local
								if (StrComp(AdatperObj_local.OriginalDisplayName,AdapterName,vbTextCompare) = 0) Then
									SetWMIInfo AdatperObj_local,PHYSICAL_ADAPTER,NameServerList,NetBiosOption
								end if
							Next

						Else
							wscript.echo "Adapter Does not exist."
						End if 
					End if

				Loop	
			End if																		
		Loop
		
	End if
	wscript.echo "Finished restoring WINS settings"
End Sub

Const PHYSICAL_ADAPTER = 0
Const VLAN_ADAPTER = 1
Const TEAM_ADAPTER = 2

'=====================================================================================
'
' Sub:	RestoreStaticIPSettings(ByVal strInputFname)'
'   
'=====================================================================================

Sub RestoreStaticIPSettings(ByVal strInputFname)
	Dim fso
	Dim wbemServices_local
	Dim TeamSets,TeamObj,VLANSets,VlanObj,AdatperSets_local,AdatperObj_local
	Dim ts, strLine
	Dim IPAddress(),IPSubnet(),IPGateway(),IPDNS,TeamName,VlanName,AdapterName
	Dim gIndex
	Dim ResetSettings

	Set wbemServices_local = GetObject("winmgmts:{impersonationLevel=impersonate}//./root/IntelNcs2")		
	
	Set fso = CreateObject("Scripting.FileSystemObject")
	
	If fso.FileExists (strInputFname) <> True Then
		Wscript.Echo "The file " & strInputFname
		Wscript.Echo "could not be found."
		Wscript.Echo "Either the file or the directory has been deleted "
		WScript.Echo "or Restore is being run on a cloned system."
		WScript.Echo "Unable to restore Static IP Addresses."	
		bError = TRUE
		Exit Sub
	Else	
		Set ts = fso.OpenTextFile(strInputFname, 1)
		
		ReDim Preserve IPAddress(-1)
		ReDim Preserve IPSubnet(-1)
		ReDim Preserve IPGateway(-1)
		IPDNS = ""
			
		Do Until ts.AtEndOfStream		

			strLine = ts.ReadLine()
			If StrComp(strLine,"Team", vbTextCompare) = 0 Then			
				strLine = ts.ReadLine()
				'Store Team Name
				TeamName = Mid(strLine,11)								
				strLine = ts.ReadLine()				
				If StrComp(strLine,"IPADDRESSES", vbTextCompare) = 0 Then
					'Store IP Addresses
					gIndex = -1
					Redim IPAddress(-1)
					strLine = ts.ReadLine()
					Do While (StrComp(strLine,"SUBNETMASKS", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
						gIndex = gIndex + 1
						ReDim Preserve IPAddress(gIndex)
						IPAddress(gIndex) = strLine
						strLine = ts.ReadLine()
					Loop
					
					'Store Subnet Masks
					gIndex = -1
					Redim IPSubnet(-1)
					If StrComp(strLine,"SUBNETMASKS", vbTextCompare) = 0 Then
						strLine = ts.ReadLine()
						Do While (StrComp(strLine,"GATEWAYADDRESSES", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
							gIndex = gIndex + 1
							ReDim Preserve IPSubnet(gIndex)
							IPSubnet(gIndex) = strLine
							strLine = ts.ReadLine()
						Loop
					End If
					
					'Store Gateway Addresses
					gIndex = -1
					Redim IPGateway(-1)
					If StrComp(strLine,"GATEWAYADDRESSES", vbTextCompare) = 0 Then
						strLine = ts.ReadLine()
						Do While (StrComp(strLine,"DNSADDRESSES", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
							gIndex = gIndex + 1
							ReDim Preserve IPGateway(gIndex)
							IPGateway(gIndex) = strLine
							strLine = ts.ReadLine()
						Loop
					End If

					'Store DNS Addresses
					IPDNS = ""
					If StrComp(strLine,"DNSADDRESSES", vbTextCompare) = 0 Then
						strLine = ts.ReadLine()
						IPDNS = strLine
						strLine = ts.ReadLine()
					End If	
				
					Set TeamSets = wbemServices_local.InstancesOf("IANet_LogicalEthernetAdapter")
					For each TeamObj in TeamSets					
						if (StrComp(Mid(TeamObj.Caption,8),TeamName,VbTextCompare) = 0) then
							SetIPInfo TeamObj,TEAM_ADAPTER,IPAddress,IPSubnet,IPGateway,IPDNS				
						End If
					Next
					if(StrComp(strLine,"VLAN", vbTextCompare) = 0) Then					
						Do while StrComp(strLine, "", vbTextCompare) <> 0											
							strLine = ts.ReadLine()
							VlanName = Mid(strLine,11)										
							strLine = ts.ReadLine()	
							If StrComp(strLine,"IPADDRESSES", vbTextCompare) = 0 Then
								'Store IP Addresses
								gIndex = -1
								Redim IPAddress(-1)
								strLine = ts.ReadLine()
								Do While (StrComp(strLine,"SUBNETMASKS", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
									gIndex = gIndex + 1
									ReDim Preserve IPAddress(gIndex)
									IPAddress(gIndex) = strLine
									strLine = ts.ReadLine()
								Loop
								
								'Store Subnet Masks
								gIndex = -1
								Redim IPSubnet(-1)
								If StrComp(strLine,"SUBNETMASKS", vbTextCompare) = 0 Then
									strLine = ts.ReadLine()
									Do While (StrComp(strLine,"GATEWAYADDRESSES", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
										gIndex = gIndex + 1
										ReDim Preserve IPSubnet(gIndex)
										IPSubnet(gIndex) = strLine
										strLine = ts.ReadLine()
									Loop
								End If
								
								'Store Gateway Addresses
								gIndex = -1
								Redim IPGateway(-1)
								If StrComp(strLine,"GATEWAYADDRESSES", vbTextCompare) = 0 Then
									strLine = ts.ReadLine()
									Do While (StrComp(strLine,"DNSADDRESSES", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
										gIndex = gIndex + 1
										ReDim Preserve IPGateway(gIndex)
										IPGateway(gIndex) = strLine
										'wscript.echo strLine
										strLine = ts.ReadLine()
									Loop
								End If

								'Store DNS Addresses
								IPDNS = ""
								If StrComp(strLine,"DNSADDRESSES", vbTextCompare) = 0 Then
									strLine = ts.ReadLine()
									IPDNS = strLine
									strLine = ts.ReadLine()
								End If
									
								Set VLANSets = wbemServices_local.InstancesOf("IANet_VLAN")			
								For each VlanObj in VLANSets												
									If (StrComp(VlanObj.VLANName,VlanName,VbTextCompare) = 0) then
										If (InStr(1,VlanObj.Caption, TeamName, 1) <> 0) then
											SetIPInfo VlanObj,VLAN_ADAPTER,IPAddress,IPSubnet,IPGateway,IPDNS				
											exit for
										End if
									End If
								Next
							Else
								'wscript.echo"Nothing to set Vlan-Team"			
								'exit do
							End if						
						Loop					
					End if
				ElseIf(StrComp(strLine,"VLAN", vbTextCompare) = 0) Then	
					Do while StrComp(strLine, "", vbTextCompare) <> 0					
						strLine = ts.ReadLine()
						VlanName = Mid(strLine,11)										
						strLine = ts.ReadLine()	
						If StrComp(strLine,"IPADDRESSES", vbTextCompare) = 0 Then
							'Store IP Addresses
							gIndex = -1
							Redim IPAddress(-1)
							strLine = ts.ReadLine()
							Do While (StrComp(strLine,"SUBNETMASKS", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
								gIndex = gIndex + 1
								ReDim Preserve IPAddress(gIndex)
								IPAddress(gIndex) = strLine
								strLine = ts.ReadLine()
							Loop
							
							'Store Subnet Masks
							gIndex = -1
							Redim IPSubnet(-1)
							If StrComp(strLine,"SUBNETMASKS", vbTextCompare) = 0 Then
								strLine = ts.ReadLine()
								Do While (StrComp(strLine,"GATEWAYADDRESSES", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
									gIndex = gIndex + 1
									ReDim Preserve IPSubnet(gIndex)
									IPSubnet(gIndex) = strLine
									strLine = ts.ReadLine()
								Loop
							End If
							
							'Store Gateway Addresses
							gIndex = -1
							Redim IPGateway(-1)
							If StrComp(strLine,"GATEWAYADDRESSES", vbTextCompare) = 0 Then
								strLine = ts.ReadLine()
								Do While (StrComp(strLine,"DNSADDRESSES", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
									gIndex = gIndex + 1
									ReDim Preserve IPGateway(gIndex)
									IPGateway(gIndex) = strLine
									'wscript.echo strLine
									strLine = ts.ReadLine()
								Loop
							End If
							
							'Store DNS Addresses
							IPDNS = ""
							If StrComp(strLine,"DNSADDRESSES", vbTextCompare) = 0 Then
								strLine = ts.ReadLine()
								IPDNS = strLine
								strLine = ts.ReadLine()
							End If
								
							Set VLANSets = wbemServices_local.InstancesOf("IANet_VLAN")			
							For each VlanObj in VLANSets												
								If (StrComp(VlanObj.VLANName,VlanName,VbTextCompare) = 0) then
									If (InStr(1,VlanObj.Caption, TeamName, 1) <> 0) then
										SetIPInfo VlanObj,VLAN_ADAPTER,IPAddress,IPSubnet,IPGateway,IPDNS				
										exit for
									End if
								End If
							Next
						Else
							'wscript.echo"Nothing to set Vlan-Team"										
						End if						
					Loop
				Else 
					'wscript.echo"Nothing to set Team"			
				End if				
			ElseIf(StrComp(Mid(strLine,1,13),"Adapter Name=", vbTextCompare) = 0) Then	
				Do while StrComp(strLine, "", vbTextCompare) <> 0				
					AdapterName = Mid(strLine,14)								
					strLine = ts.ReadLine()
				
					If(StrComp(strLine,"VLAN", vbTextCompare) = 0) Then							
						strLine = ts.ReadLine()
						VlanName = Mid(strLine,11)										
						strLine = ts.ReadLine()	
						If StrComp(strLine,"IPADDRESSES", vbTextCompare) = 0 Then
							'Store IP Addresses
							gIndex = -1
							Redim IPAddress(-1)
							strLine = ts.ReadLine()
							Do While (StrComp(strLine,"SUBNETMASKS", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
								gIndex = gIndex + 1
								ReDim Preserve IPAddress(gIndex)
								IPAddress(gIndex) = strLine
								strLine = ts.ReadLine()
							Loop
							
							'Store Subnet Masks
							gIndex = -1
							Redim IPSubnet(-1)
							If StrComp(strLine,"SUBNETMASKS", vbTextCompare) = 0 Then
								strLine = ts.ReadLine()
								Do While (StrComp(strLine,"GATEWAYADDRESSES", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
									gIndex = gIndex + 1
									ReDim Preserve IPSubnet(gIndex)
									IPSubnet(gIndex) = strLine
									strLine = ts.ReadLine()
								Loop
							End If
							
							'Store Gateway Addresses
							gIndex = -1
							Redim IPGateway(-1)
							If StrComp(strLine,"GATEWAYADDRESSES", vbTextCompare) = 0 Then
								strLine = ts.ReadLine()
								Do While (StrComp(strLine,"DNSADDRESSES", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
									gIndex = gIndex + 1
									ReDim Preserve IPGateway(gIndex)
									IPGateway(gIndex) = strLine
									'wscript.echo strLine
									strLine = ts.ReadLine()
								Loop
							End If
							
							'Store DNS Addresses
							IPDNS = ""
							If StrComp(strLine,"DNSADDRESSES", vbTextCompare) = 0 Then
								strLine = ts.ReadLine()
								IPDNS = strLine
								strLine = ts.ReadLine()
							End If
								
							Set VLANSets = wbemServices_local.InstancesOf("IANet_VLAN")			
							For each VlanObj in VLANSets												
								If (StrComp(VlanObj.VLANName,VlanName,VbTextCompare) = 0) then
									If (InStr(1,VlanObj.Caption, AdapterName, 1) <> 0) then
										SetIPInfo VlanObj,VLAN_ADAPTER,IPAddress,IPSubnet,IPGateway,IPDNS	
									End if			
								End If
							Next
						Else
							'Wscript.echo"Nothing to set vlan-adapter"										
						End if
					Else
						If StrComp(strLine,"IPADDRESSES", vbTextCompare) = 0 Then
							'Store IP Addresses
							gIndex = -1
							Redim IPAddress(-1)
							strLine = ts.ReadLine()
							Do While (StrComp(strLine,"SUBNETMASKS", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
								gIndex = gIndex + 1
								ReDim Preserve IPAddress(gIndex)
								IPAddress(gIndex) = strLine
								strLine = ts.ReadLine()
							Loop
              
							'Store Subnet Masks
							gIndex = -1
							Redim IPSubnet(-1)
							If StrComp(strLine,"SUBNETMASKS", vbTextCompare) = 0 Then
								strLine = ts.ReadLine()
								Do While (StrComp(strLine,"GATEWAYADDRESSES", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
									gIndex = gIndex + 1
									ReDim Preserve IPSubnet(gIndex)
									IPSubnet(gIndex) = strLine
									strLine = ts.ReadLine()
								Loop
							End If
							
							'Store Gateway Addresses
							gIndex = -1
							Redim IPGateway(-1)
							If StrComp(strLine,"GATEWAYADDRESSES", vbTextCompare) = 0 Then
								strLine = ts.ReadLine()
								Do While (StrComp(strLine,"DNSADDRESSES", vbTextCompare) <> 0) And (StrComp(strLine,"", vbTextCompare) <> 0)
									gIndex = gIndex + 1
									ReDim Preserve IPGateway(gIndex)
									IPGateway(gIndex) = strLine
									'wscript.echo strLine
									strLine = ts.ReadLine()
								Loop
							End If
							
							'Store DNS Addresses
							IPDNS = ""
							If StrComp(strLine,"DNSADDRESSES", vbTextCompare) = 0 Then
								strLine = ts.ReadLine()
								IPDNS = strLine
								strLine = ts.ReadLine()
							End If
							
							Set AdatperSets_local = wbemServices_local.InstancesOf("IANet_PhysicalEthernetAdapter")
							For each AdatperObj_local In AdatperSets_local
								if (StrComp(AdatperObj_local.OriginalDisplayName,AdapterName,vbTextCompare) = 0) Then
									SetIPInfo AdatperObj_local,PHYSICAL_ADAPTER,IPAddress,IPSubnet,IPGateway,IPDNS
								end if
							Next

						Else
							wscript.echo "Adapter Does not exist."
						End if 
					End if

				Loop	
			End if																		
		Loop
		
	End if
	wscript.echo "Finished restoring Static IP addresses"
End Sub

'*****************************************************************************
Sub ReloadLogicalDevice(ResetSettings,WbemServices)
	Dim ResetSettingObj
	Dim OriginalVal

	For Each ResetSettingObj in ResetSettings
		OriginalVal = ResetSettingObj.CurrentValue

		' Do a BeginApply to acquire a lock in Middleware to prepare to write a setting
		Err.Clear
		Dim ClientID, dummyResult
		Dim BeginApplyNetServiceObject
		Dim colBeginApplyNetServiceObject : Set colBeginApplyNetServiceObject = WbemServices.ExecQuery("Select * from IANet_NetService", , 16)
		WbemServices.Security_.Privileges.AddAsString "SeLoadDriverPrivilege", True
		If IsObject(colBeginApplyNetServiceObject) Then
			For Each BeginApplyNetServiceObject In colBeginApplyNetServiceObject
				Dim objReturn : Set objReturn = BeginApplyNetServiceObject.ExecMethod_("BeginApply")  
				If objReturn.ReturnValue = 0 Then
					ClientID = Cint(objReturn.ClientSetHandle)
				Else
					sReturn =  "Unable to establish to obtain client lock ID" & GetErr
					Err.Clear
				End If     
			Next
		Else
			sReturn =  "Unable to obtain instances of IANet_NetService " & GetErr
			Err.Clear
		End If
		
		dim SValueSet : Set SValueSet = CreateObject("WbemScripting.SWbemNamedValueSet")

		' Add the ClientID so the lock allows us to apply the setting
		SValueSet.Add "ClientSetId", ClientID
		' Update the setting to what we want it to be
		ResetSettingObj.CurrentValue = OriginalVal
		' Call WMI to update the setting
		Set dummyResult = ResetSettingObj.Put_(&h20000, SValueSet)	

		' Try to apply the setting	
		Err.Clear
		Dim ApplyNetServiceObject
		Dim colApplyNetServiceObject : Set colApplyNetServiceObject = WbemServices.ExecQuery("Select * from IANet_NetService", , 16)
		If IsObject(colApplyNetServiceObject) Then
			For Each ApplyNetServiceObject In colApplyNetServiceObject
				'Spawn IN parameters for 'Apply'
				Dim objInParams : Set objInParams = ApplyNetServiceObject.Methods_.Item("Apply").InParameters.SpawnInstance_()
				'Set ClientID
				objInParams.ClientSetHandle = ClientID
				'Invoke method         
				Dim objApplyReturn : Set objApplyReturn = ApplyNetServiceObject.ExecMethod_("Apply", objInParams)
				'Evaluate return codes
				If objApplyReturn.ReturnValue = 0 Then
					'Evaluate FollowUpAction (0 = no reboot, 1 = reboot)
					If objApplyReturn.FollowUpAction = 1 Then
						Wscript.Echo "A reboot is required"
					End If
				End If    
			Next
		End If
	Next
End Sub

'*****************************************************************************
Sub SetIPInfo(ConnectionObj,ConnectionType,IPAddress,IPSubnet,IPGateway,IPDNS)
	Dim colWMISettings,objWMISetting
	Dim settingType
	Dim Dumbpath
	Dim SettingVal
	Dim i
	
	Const wbemFlagUseAmendedQualifiers = &h20000
	
	i = 0		
	For i=LBound(IPAddress) To UBound(IPAddress)
		wscript.Echo"IPAddress : " & IPAddress(i)
		wscript.Echo"IPSubnet : " & IPSubnet(i)
	Next
	
	If (ConnectionType = PHYSICAL_ADAPTER) Then
		settingType = "IANet_AdapterSetting"
	Elseif (ConnectionType = VLAN_ADAPTER) Then
		settingType = "IANet_VLANSetting"
	Elseif (ConnectionType = TEAM_ADAPTER) Then
		settingType = "IANet_TeamSetting"
	Else
		settingType = ""
	End If
	
	CreateSessions()
	Set colWMISettings = wbemServices.ExecQuery("ASSOCIATORS OF {" & ConnectionObj.Path_.Path & "} WHERE ResultClass = " & settingType,,,SValueSet)
	
	For Each objWMISetting In colWMISettings
		If StrComp(objWMISetting.Caption, "EnableDHCP", vbTextCompare) = 0 Then
			If objWMISetting.CurrentValue = 1 Then
				objWMISetting.CurrentValue = 0
				Set Dumbpath = objWMISetting.Put_(wbemFlagUseAmendedQualifiers,SValueSet)
				Exit For
			End If
		End If
	Next
	
	ExecApply wbemServices, strNetSerObjPath, SessionObject

	WScript.Sleep(2000)
	
	CreateSessions()
	Set colWMISettings = wbemServices.ExecQuery("ASSOCIATORS OF {" & ConnectionObj.Path_.Path & "} WHERE ResultClass = " & settingType,,,SValueSet)
	
	For Each objWMISetting In colWMISettings
		If StrComp(objWMISetting.Caption, "IPAddress", vbTextCompare) = 0 Then
			If UBound(IPAddress) > -1 Then
				If StrComp(IPAddress(0), "0.0.0.0", vbTextCompare) <> 0 Then
					objWMISetting.CurrentValues = IPAddress
					Set Dumbpath = objWMISetting.Put_(wbemFlagUseAmendedQualifiers,SValueSet)
				End If
			End If
		Elseif StrComp(objWMISetting.Caption, "SubnetMask", vbTextCompare) = 0 Then
			If UBound(IPSubnet) > -1 Then
				If StrComp(IPSubnet(0), "0.0.0.0", vbTextCompare) <> 0 Then
					objWMISetting.CurrentValues = IPSubnet
					Set Dumbpath = objWMISetting.Put_(wbemFlagUseAmendedQualifiers,SValueSet)
				End If
			End If
		Elseif StrComp(objWMISetting.Caption, "DefaultGateway", vbTextCompare) = 0 Then
			If UBound(IPGateway) > -1 Then
				If StrComp(IPGateway(0), "0.0.0.0", vbTextCompare) <> 0 Then
					objWMISetting.CurrentValues = IPGateway
					Set Dumbpath = objWMISetting.Put_(wbemFlagUseAmendedQualifiers,SValueSet)
				End If
			End If
		Elseif StrComp(objWMISetting.Caption, "NameServer", vbTextCompare) = 0 Then
			If (StrComp(IPDNS, "", vbTextCompare) <> 0) AND (StrComp(IPDNS, "0.0.0.0", vbTextCompare) <> 0) Then
				objWMISetting.CurrentValue = IPDNS
				Set Dumbpath = objWMISetting.Put_(wbemFlagUseAmendedQualifiers,SValueSet)
			End If
		End If
	Next
	
	ExecApply wbemServices, strNetSerObjPath, SessionObject
End Sub

'*****************************************************************************
Sub SetWMIInfo(ConnectionObj,ConnectionType,NameList,NetBios)
    Dim colWMISettings,objWMISetting
    Dim settingType
    Dim Dumbpath
    Dim SettingVal
    Dim i
    Dim CurrentNameListCol
        Dim bFoundMatch, bRestoreWINS, CurrentNameServerList
    
    Const wbemFlagUseAmendedQualifiers = &h20000
    
    i = 0		
    For i=LBound(NameList) To UBound(NameList)
        If StrComp(NameList(i), "", vbTextCompare) <> 0 Then
            wscript.Echo"NameList : " & NameList(i)
        End If
    Next
    
    If (ConnectionType = PHYSICAL_ADAPTER) Then
        settingType = "IANet_AdapterSetting"
    Elseif (ConnectionType = VLAN_ADAPTER) Then
        settingType = "IANet_VLANSetting"
    Elseif (ConnectionType = TEAM_ADAPTER) Then
        settingType = "IANet_TeamSetting"
    Else
        settingType = ""
    End If	

    WScript.Sleep(2000)
    
    CreateSessions()
    Set colWMISettings = wbemServices.ExecQuery("ASSOCIATORS OF {" & ConnectionObj.Path_.Path & "} WHERE ResultClass = " & settingType,,,SValueSet)
    
    'Loop through each setting item
    For Each objWMISetting In colWMISettings
        'If the setting is NAMERSERVERLIST
        If StrComp(objWMISetting.Caption, "NAMESERVERLIST", vbTextCompare) = 0 Then
            'If the passed in NameList is not empty
            If UBound(NameList) > -1 Then
                i = 0
                bRestoreWINS = false
                'For each element in passed in array
                For i=LBound(NameList) To UBound(NameList)
                    bFoundMatch = false
                    CurrentNameListCol = objWMISetting.CurrentValues
                    
                    'If setting passed from WMI and the passed in setting are empty there is essentialy a match
                    if((UBound(CurrentNameListCol) = -1) and (StrComp(NameList(i), "", vbTextCompare) = 0)) then
                        bFoundMatch = true

                    'else if the number of items in name list array from WMI is different than passed in, we need to restore setting
                    elseif(UBound(CurrentNameListCol) <> UBound(NameList)) then 
                        bRestoreWINS = true
                        Exit For

                    'else compare each item from the WMI setting to the array passed in to see if there is a match
                    else
                        For Each CurrentNameServerList In CurrentNameListCol
                            'If there is a match mark it
                            If (StrComp(CurrentNameServerList, NameList(i), vbTextCompare) = 0) Then
                                bFoundMatch = true
                                Exit For   
                            End If
                        Next
                    End if

                    'If there was no match with the current passed in name list array, then we need to restore the setting
                    if bFoundMatch = false then
                        bRestoreWINS = true
                        Exit For
                    End If
                Next

                if bRestoreWINS = true then
                    objWMISetting.CurrentValues = NameList
                    Set Dumbpath = objWMISetting.Put_(wbemFlagUseAmendedQualifiers,SValueSet)
                End If
            End If
        Elseif StrComp(objWMISetting.Caption, "NETBIOSOPTIONS", vbTextCompare) = 0 Then
            If (StrComp(NetBios, "", vbTextCompare) <> 0) and (StrComp(objWMISetting.CurrentValue, NetBios, vbTextCompare) <> 0) Then
                objWMISetting.CurrentValue = NetBios
                Set Dumbpath = objWMISetting.Put_(wbemFlagUseAmendedQualifiers,SValueSet)
            End If
        End If
    Next
    
    ExecApply wbemServices, strNetSerObjPath, SessionObject
End Sub

'*****************************************************************************
Sub SaveStaticIPSettings(byVal strOutputFileName)
	dim colNetDevicesPhysical,colNetDevicesLogical
	dim objNetDevicePhyObj,objFile,objNetDeviceLogObj
	dim wbemServices,objWMIService
    dim objWINSFile
    dim fso
    dim Capability
	dim bIsLADIntelDevice

    'Create WINS config file
    Set fso = CreateObject("Scripting.FileSystemObject")
    Set objWINSFile=fso.CreateTextFile(WINSFilePath,True)

	objWINSFile.WriteLine "*** NCS2 DMiX WINS information  ***"
	objWINSFile.WriteLine "*** Date " & Date & " Time " & Time() & "  ***"
	objWINSFile.WriteLine "**********************************************"
	objWINSFile.WriteLine ""
	
	'Create IP configuration file
	If IsEmpty(CreateConfigFile(strOutputFileName)) then
		Exit Sub
	Else
		Set objFile=CreateConfigFile(strOutputFileName)
	End If
	objFile.WriteLine "*** NCS2 DMiX IP information  ***"
	objFile.WriteLine "*** Date " & Date & " Time " & Time() & "  ***"
	objFile.WriteLine "**********************************************"
	objFile.WriteLine ""
    objWINSFile.close	
	
	Set wbemServices = GetObject("winmgmts:{impersonationLevel=impersonate}//./root/IntelNcs2")	
	wbemServices.Security_.Privileges.AddAsString "SeLoadDriverPrivilege", True
		
	'Get all instances from IANet_PhysicalEthernetAdapter for adapters
	
	Set colNetDevicesPhysical = wbemServices.InstancesOf("IANet_PhysicalEthernetAdapter") 
	For each objNetDevicePhyObj in colNetDevicesPhysical
		bIsLADIntelDevice = false
		
		IsIntelDevice objNetDevicePhyObj, bIsLADIntelDevice

            	if(bIsLADIntelDevice and objNetDevicePhyObj.StatusInfo = 3) then			
			SaveIPInfo objFile,objNetDevicePhyObj,VLAN_ADAPTER				
			SaveIPInfo objFile,objNetDevicePhyObj,PHYSICAL_ADAPTER			
		End if
	Next
	
	objFile.WriteBlankLines(1)
    Set objWINSFile=fso.OpenTextFile(WINSFilePath,8,true)
    objWINSFile.WriteBlankLines(1)
    objWINSFile.close
	
	'Get all instances from IANet_LogicalEthernetAdapter for teams
	Set colNetDevicesLogical = wbemServices.InstancesOf("IANet_LogicalEthernetAdapter") 
	
	' SCR 50668 Fix:  Without ANS installed, the IANet_LogicalEthernetAdapter class
	' Is not exposed in the WMI, causing the for each loop below to fail.  Since 
	' isNull() and isEmpty() are not reflecting when IANet_LogicalEthernetAdapter
	' is not there, it was needed to be done like this.  
	
	' Turn on error handling (script does not halt on errors)
	On Error Resume Next
		For each objNetDeviceLogObj in colNetDevicesLogical		
			' Check if there was an error accessing the Logical Adapter collection
			' if not, save the ANS information
			if err.number = 0 then
				SaveIPInfo objFile,objNetDeviceLogObj,TEAM_ADAPTER					
				SaveIPInfo objFile,objNetDeviceLogObj,VLAN_ADAPTER
				SaveIPInfo objFile,objNetDeviceLogObj,PHYSICAL_ADAPTER
			end if
		Next
	' Turn off error handling (script halts on errors again)
	On Error Goto 0

	objFile.WriteBlankLines(1)
    Set objWINSFile=fso.OpenTextFile(WINSFilePath,8,true)
    objWINSFile.WriteBlankLines(1)
    objWINSFile.close
	
	objFile.close
	Wscript.Echo "Static IP information saved!"
End Sub

'*****************************************************************************
Private Function CreateIPConfigFile(byVal strOutputFileName)
	dim fso
	dim file
	Dim szTmpFld
	Set fso = CreateObject("Scripting.FileSystemObject")
	szTmpFld = shell.ExpandEnvironmentStrings("%TEMP%")
	If (fso.FolderExists(szTmpFld)) <> True Then
		Wscript.Echo ""
		Wscript.Echo "Unable to create the configuration file required"
		Wscript.Echo "to save the static IP information."
		Wscript.Echo "Static IP information will not be saved."
		bError = TRUE
		Exit Function
	End If
	szTmpFld = szTmpFld & "\PROSetDX\DMIX\"
	'make sure the folder exists before creating the text file
	If (fso.FolderExists(szTmpFld)) <> True Then
		'need to create destination folder one directory at a time
		szTmpFld = shell.ExpandEnvironmentStrings("%TEMP%")
		szTmpFld = szTmpFld & "\PROSetDX"
		If (fso.FolderExists(szTmpFld)) <> True Then
			fso.CreateFolder(szTmpFld)
		End If
		szTmpFld = szTmpFld & "\DMIX"
		fso.CreateFolder(szTmpFld)
		If (fso.FolderExists(szTmpFld)) <> True Then
			Wscript.Echo ""
			Wscript.Echo "Unable to create the configuration file required"
			Wscript.Echo "to save the static IP information."
			Wscript.Echo "Static IP information will not be saved."
			bError = TRUE
			Exit Function
		End If
	End If
	Set file=fso.CreateTextFile(strOutputFileName,True)
	Set CreateIPConfigFile=file
End Function

'****************************************************************************
Private Function SaveIPInfo(objFile,objAdapter,adapterType)
	Dim objWMIService
	Dim colWMISettings,objWMISetting
	Dim colLogicalAdapter,objLogicalAdapter
	Dim col802dot1VLAN,obj802dot1VLAN,colVLAN,objVLAN
	Dim cont
    Dim objWINSFile
    Dim fso
	
	Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}//./root/IntelNcs2")
	cont = True

    'Store WINS file information
    Set fso = CreateObject("Scripting.FileSystemObject")
	Set objWINSFile=fso.OpenTextFile(WINSFilePath,8,true)
	
	'Check whether static IP information is available through WMI
	If (adapterType = PHYSICAL_ADAPTER) Then
		Set colWMISettings = objWMIService.ExecQuery("ASSOCIATORS OF {" & objAdapter.Path_.Path & "} WHERE ResultClass = IANet_AdapterSetting")
		For Each objWMISetting In colWMISettings
			If (StrComp(objWMISetting.Caption, "EnableDHCP", vbTextCompare) = 0) Then
				If (objWMISetting.CurrentValue = 0) Then
					objFile.WriteLine "Adapter Name=" & objAdapter.OriginalDisplayName
					SaveWMIIPInfo objFile,colWMISettings,objAdapter.DeviceID
				End If
                'WINS settings
                objWINSFile.WriteLine "Adapter Name=" & objAdapter.OriginalDisplayName
                SaveWINSInfo objWINSFile,colWMISettings,objAdapter.DeviceID
                cont = False
			End If
		Next
	Elseif (adapterType = VLAN_ADAPTER) Then
		Set col802dot1VLAN = objWMIService.ExecQuery("ASSOCIATORS OF {" & objAdapter.Path_.Path & "} WHERE ResultClass = IANet_802dot1QVLANService")
		If col802dot1VLAN.Count > 0 Then			
			For Each obj802dot1VLAN In col802dot1VLAN		  
				Set colVLAN = objWMIService.ExecQuery("ASSOCIATORS OF {" & obj802dot1VLAN.Path_.Path & "} WHERE ResultClass = IANet_VLAN")
				If colVLAN.Count > 0 Then								
					For Each objVLAN In colVLAN
						Set colWMISettings = objWMIService.ExecQuery("ASSOCIATORS OF {" & objVLAN.Path_.Path & "} WHERE ResultClass = IANet_VLANSetting")
						For Each objWMISetting In colWMISettings
							If (StrComp(objWMISetting.Caption, "EnableDHCP", vbTextCompare) = 0) Then
								If (objWMISetting.CurrentValue = 0) Then
									If (objVLAN.ParentType = 0) Then
										objFile.WriteLine "Adapter Name=" & objAdapter.Caption
										objFile.WriteLine "VLAN"						
										objFile.WriteLine "VLAN Name=" & objVLAN.VLANName
									Elseif (objVLAN.ParentType = 1) Then
										objFile.WriteLine "Team" 
										objFile.WriteLine "Team Name=" & Mid(objAdapter.Caption,8)
										objFile.WriteLine "VLAN"						
										objFile.WriteLine "VLAN Name=" & objVLAN.VLANName
									Else
										objFile.WriteLine "VLAN"						
										objFile.WriteLine "VLAN Name=" & objVLAN.VLANName
									End If
									SaveWMIIPInfo objFile,colWMISettings,objVLAN.Name
								End If
                                'WINS settings
                                If (objVLAN.ParentType = 0) Then
								    objWINSFile.WriteLine "Adapter Name=" & objAdapter.Caption
								    objWINSFile.WriteLine "VLAN"						
								    objWINSFile.WriteLine "VLAN Name=" & objVLAN.VLANName
							    Elseif (objVLAN.ParentType = 1) Then
								    objWINSFile.WriteLine "Team" 
								    objWINSFile.WriteLine "Team Name=" & Mid(objAdapter.Caption,8)
								    objWINSFile.WriteLine "VLAN"						
								    objWINSFile.WriteLine "VLAN Name=" & objVLAN.VLANName
							    Else
								    objWINSFile.WriteLine "VLAN"						
								    objWINSFile.WriteLine "VLAN Name=" & objVLAN.VLANName
							    End If
                                SaveWINSInfo objWINSFile,colWMISettings,objVLAN.Name
								cont = False
							End If
						Next					
					Next
				End If
			Next
		End If
	Elseif (adapterType = TEAM_ADAPTER) Then
		Set colWMISettings = objWMIService.ExecQuery("ASSOCIATORS OF {" & objAdapter.Path_.Path & "} WHERE ResultClass = IANet_TeamSetting")
		For Each objWMISetting In colWMISettings
			If (StrComp(objWMISetting.Caption, "EnableDHCP", vbTextCompare) = 0) Then
				If (objWMISetting.CurrentValue = 0) Then
					objFile.WriteLine "Team" 
					objFile.WriteLine "Team Name=" & Mid(objAdapter.Caption,8)
					SaveWMIIPInfo objFile,colWMISettings,objAdapter.DeviceID
				End If
                objWINSFile.WriteLine "Team" 
				objWINSFile.WriteLine "Team Name=" & Mid(objAdapter.Caption,8)
				SaveWINSInfo objWINSFile,colWMISettings,objAdapter.DeviceID
				cont = False
			End If
		Next
	End If
	
	'Check whether static IP information is available in registry
	If (cont = True) Then
		On Error Resume Next
		If (adapterType = PHYSICAL_ADAPTER) Then
			Set colLogicalAdapter = objWMIService.InstancesOf("IANet_PhysicalEthernetAdapter where StaticIPAddress <> '0.0.0.0'")
			For Each objLogicalAdapter In colLogicalAdapter
				If Err.Number = 0 Then
					On Error Goto 0
					If objLogicalAdapter.DeviceID = objAdapter.DeviceID Then
						objFile.WriteLine "Adapter Name=" & objAdapter.OriginalDisplayName
						SaveLegacyIPInfo objFile,objAdapter.DeviceID
					End If
				End If
			Next
		Elseif (adapterType = VLAN_ADAPTER) Then
			Set col802dot1VLAN = objWMIService.ExecQuery("ASSOCIATORS OF {" & objAdapter.Path_.Path & "} WHERE ResultClass = IANet_802dot1QVLANService")
			If col802dot1VLAN.Count > 0 Then			
				For Each obj802dot1VLAN In col802dot1VLAN		  
					Set colVLAN = objWMIService.ExecQuery("ASSOCIATORS OF {" & obj802dot1VLAN.Path_.Path & "} WHERE ResultClass = IANet_VLAN")
					For Each objVLAN In colVLAN
						Set colLogicalAdapter = objWMIService.InstancesOf("IANet_VLAN where StaticIPAddress <> '0.0.0.0'")
						For Each objLogicalAdapter In colLogicalAdapter
							If objLogicalAdapter.Name = objVLAN.Name Then
								If Err.Number = 0 Then
									On Error Goto 0
									If (objVLAN.ParentType = 0) Then
										objFile.WriteLine "Adapter Name=" & objAdapter.Caption
										objFile.WriteLine "VLAN"						
										objFile.WriteLine "VLAN Name=" & objVLAN.VLANName
									Elseif (objVLAN.ParentType = 1) Then
										objFile.WriteLine "Team" 
										objFile.WriteLine "Team Name=" & Mid(objAdapter.Caption,8)
										objFile.WriteLine "VLAN"						
										objFile.WriteLine "VLAN Name=" & objVLAN.VLANName
									Else
										objFile.WriteLine "VLAN"						
										objFile.WriteLine "VLAN Name=" & objVLAN.VLANName
									End If
									SaveLegacyIPInfo objFile,objVLAN.Name
								End If
							End If
						Next					
					Next
				Next
			End If
		Elseif (adapterType = TEAM_ADAPTER) Then
			Set colLogicalAdapter = objWMIService.InstancesOf("IANet_TeamofAdapters where StaticIPAddress <> '0.0.0.0'")
			For Each objLogicalAdapter In colLogicalAdapter
				If Err.Number = 0 Then
					On Error Goto 0
					If objLogicalAdapter.Name = objAdapter.DeviceID Then
						objFile.WriteLine "Team" 
						objFile.WriteLine "Team Name=" & Mid(objAdapter.Caption, 8)
						SaveLegacyIPInfo objFile,objAdapter.DeviceID
					End If
				End If
			Next
		End If
		On Error Goto 0
	End If

    objWINSFile.close
	
End Function

'****************************************************************************
Private Function SaveWINSInfo(objWINSFile,colWMISettings,adapterID)
    Dim objWMISetting
	Dim itemWINSNameServerListCol,itemWINSNameServerList
	Dim itemWINSNetBiosOptions
	For Each objWMISetting In colWMISettings
		If (StrComp(objWMISetting.ParentID, adapterID, vbTextCompare) = 0) Then
			If (StrComp(objWMISetting.Caption, "NameServerList", vbTextCompare) = 0) Then
				itemWINSNameServerListCol = objWMISetting.CurrentValues
			Elseif (StrComp(objWMISetting.Caption, "NetbiosOptions", vbTextCompare) = 0) Then
				itemWINSNetBiosOptions = objWMISetting.CurrentValue
			End If
		End If
	Next

    'If the length of the combined array is greater than 0, then it is not empty
    if(Len(Join(itemWINSNameServerListCol)) > 0) Then
        objWINSFile.WriteLine "NAMESERVERLIST"

        For Each itemWINSNameServerList In itemWINSNameServerListCol
		    If (StrComp(itemWINSNameServerList, " ", vbTextCompare) <> 0) Then
			    objWINSFile.WriteLine itemWINSNameServerList
		    End If
	    Next
    End If

	objWINSFile.WriteLine "NETBIOSOPTIONS"
    objWINSFile.WriteLine itemWINSNetBiosOptions
    objWINSFile.WriteBlankLines(1)
End Function

'****************************************************************************
Private Function SaveWMIIPInfo(objFile,colWMISettings,adapterID)
	Dim objWMISetting
	Dim itemIPAddress,itemListIPAddress
	Dim itemSubnetMask,itemListSubnetMask
	Dim itemDefaultGateway,itemListDefaultGateway
	Dim itemNameServer
	
	For Each objWMISetting In colWMISettings
		If (StrComp(objWMISetting.ParentID, adapterID, vbTextCompare) = 0) Then
			If (StrComp(objWMISetting.Caption, "IPAddress", vbTextCompare) = 0) Then
				itemListIPAddress = objWMISetting.CurrentValues
			Elseif (StrComp(objWMISetting.Caption, "SubnetMask", vbTextCompare) = 0) Then
				itemListSubnetMask = objWMISetting.CurrentValues
			Elseif (StrComp(objWMISetting.Caption, "DefaultGateway", vbTextCompare) = 0) Then
				itemListDefaultGateway = objWMISetting.CurrentValues
			Elseif (StrComp(objWMISetting.Caption, "NameServer", vbTextCompare) = 0) Then
				itemNameServer = objWMISetting.CurrentValue
			End If
		End If
	Next
	
	objFile.WriteLine "IPADDRESSES"
	For Each itemIPAddress In itemListIPAddress
		If (StrComp(itemIPAddress, " ", vbTextCompare) <> 0) Then
			objFile.WriteLine itemIPAddress
		End If
	Next
	objFile.WriteLine "SUBNETMASKS"
	For Each itemSubnetMask In itemListSubnetMask
		If (StrComp(itemSubnetMask, " ", vbTextCompare) <> 0) Then
			objFile.WriteLine itemSubnetMask
		End If
	Next
	objFile.WriteLine "GATEWAYADDRESSES"
	For Each itemDefaultGateway In itemListDefaultGateway
		If (StrComp(itemDefaultGateway, " ", vbTextCompare) <> 0) Then
			objFile.WriteLine itemDefaultGateway
		End If
	Next
	objFile.WriteLine "DNSADDRESSES"
	objFile.WriteLine itemNameServer
	objFile.WriteBlankLines(1)		
End Function

'****************************************************************************
Private Function SaveLegacyIPInfo(objFile,adapterID)
	Dim regAccess
	Dim keyPath,valName
	Dim regVal,strVal
	
	Const HKEY_LOCAL_MACHINE = &H80000002
	
	set regAccess = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
		
	keyPath = ("SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\" & adapterID)
	
	valName = "IPAddress"
	regAccess.GetMultiStringValue HKEY_LOCAL_MACHINE,keyPath,valName,regVal
	
	If UBound(regVal) > -1 Then
		objFile.WriteLine "IPADDRESSES"
		For Each strVal in regVal
			objFile.WriteLine strVal
		Next
	End If
	
	valName = "SubnetMask"
	regAccess.GetMultiStringValue HKEY_LOCAL_MACHINE,keyPath,valName,regVal
	
	If UBound(regVal) > -1 Then
		objFile.WriteLine "SUBNETMASKS"
		For Each strVal in regVal
			objFile.WriteLine strVal
		Next
	End If
	
	valName = "DefaultGateway"
	regAccess.GetMultiStringValue HKEY_LOCAL_MACHINE,keyPath,valName,regVal          
	
	If UBound(regVal) > -1 Then
		objFile.WriteLine "GATEWAYADDRESSES"
		For Each strVal in regVal
			objFile.WriteLine strVal
		Next
	End If
	
	valName = "NameServer"
	regAccess.GetStringValue HKEY_LOCAL_MACHINE,keyPath,valName,regVal          

	If strcomp(regVal,"",vbTextCompare) <> 0 Then
		objFile.WriteLine "DNSADDRESSES"
		objFile.WriteLine regVal
	End If
	
	objFile.WriteLine ""		
End Function

'****************************************************************************
Private Function Is_GVRP_GMRP_Setting(szReadLine)
	Dim bRet: bRet = FALSE
	If (InStr(szReadLine,"GVRP") > 0) Or _
	   (InStr(szReadLine,"GMRP") > 0) Then
	   	bRet = TRUE
	End If 	
	
	Is_GVRP_GMRP_Setting = bRet
End Function

'****************************************************************************
Private Function Is_StaticIP_Setting(szReadLine)
	Dim bRet: bRet = FALSE
	If (StrComp(szReadLine, "DefaultGateway", vbTextCompare) = 0) Or _
		(StrComp(szReadLine, "IPAddress", vbTextCompare) = 0) Or _
		(StrComp(szReadLine, "NameServer", vbTextCompare) = 0) Or _
		(StrComp(szReadLine, "SubnetMask", vbTextCompare) = 0) Or _
        (StrComp(szReadLine, "NAMESERVERLIST", vbTextCompare) = 0) Or _
		(StrComp(szReadLine, "DNSADDRESSES", vbTextCompare) = 0) Then
	   	bRet = TRUE
	End If 	
	
	Is_StaticIP_Setting = bRet
End Function

Private Function Is_ConnMon_Setting(szReadLine)

	Dim bRet: bRet = FALSE
	If (InStr(szReadLine, "ConnMonClients") > 0) Then
	   	bRet = TRUE
	End If 	
	
	Is_ConnMon_Setting= bRet

End Function

'****************************************************************************
Private Function IsTeamSupportedInCurrentOS(strTeamType)
	dim bRet: bRet = TRUE
	
'	*********************************************
'	WE ARE NO LONGER RESTRICTING TEAM TYPES IN XP
'	*********************************************
'	if ((OSVersion = "5.1") OR ((OSVersion = "5.2") AND (OSProductType = "1"))) AND (strTeamType <> "0") AND (strTeamType <> "1") then
'		bRet = FALSE
'	end if 
	
' 	ALWAYS RETURN TRUE, REVERSING DCR 170
	IsTeamSupportedInCurrentOS = bRet	
	
End function

' This function will take a passed string (szString) and break it based on (szDelimeter) into an array
function ConvertStringToStringArray(szString, szDelimeter)
	dim szArray()
	dim szTempStr
	dim szTemp
	dim arrayCounter
	arrayCounter = 0
	Redim Preserve AdapterPath(1)

	'  The only way this loop will work as written is if the input string ends with the delimeter
	'  Otherwise it will result in an infinite loop
	if InStrRev(szString, szDelimeter) <> Len(szString) then
		szString = szString + szDelimeter
	end if
	on error resume next
	do 

		
		szTemp = Left(szString, InStr(szString, szDelimeter)-1)
		
		if len(szTemp) > 0 then
			Redim preserve szArray(arrayCounter)
			szArray(arrayCounter) = szTemp
			arrayCounter = arrayCounter + 1
		end if	

		szString = Mid(szString, InStr(szString, szDelimeter)+1)
	loop until len(szString) = 0 
	on error goto 0

	ConvertStringToStringArray = szArray

end function

'****************************************************************************
Sub GetOldTimeOutValue
	Dim regAccess
	Dim keyPath,valName
	
	Const HKEY_LOCAL_MACHINE = &H80000002
	
	Set regAccess = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
		
	keyPath = ("SYSTEM\CurrentControlSet\Services\disk")
	
	valName = "TimeOutValue"
	regAccess.GetDWORDValue HKEY_LOCAL_MACHINE,keyPath,valName,oldTimeOutValue
End Sub

'****************************************************************************
Sub ShowTimeOutValueRebootMessage
	Dim regAccess
	Dim keyPath,valName
	Dim newTimeOutValue
		
	Const HKEY_LOCAL_MACHINE = &H80000002
	
	Set regAccess = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
		
	keyPath = ("SYSTEM\CurrentControlSet\Services\disk")
	
	valName = "TimeOutValue"
	regAccess.GetDWORDValue HKEY_LOCAL_MACHINE,keyPath,valName,newTimeOutValue
	
	If newTimeOutValue <> oldTimeOutValue And isTimeOutValueModified = True Then
		WScript.Echo "Restore successful. Reboot required."
	End If
End Sub

'*****************************************************************************
sub SaveHyperVSettings(settingsFileName)
	dim fileSystem, settingsFile
	dim ncsService
	dim physicalAdapters, physicalAdapter
	dim logicalAdapters, logicalAdapter
	dim vlanServices, vlanService
	dim vlanAdapters, vlanAdapter
	dim Capability
	dim bIsLADIntelDevice
	

	'Test whether Hyper-v is present or not
	
	on error resume next
	GetObject("winmgmts:\\.\root\virtualization")
	if err.number <> 0 then
		exit sub
	end if
	on error goto 0
	
	
	'Setup output file

	set fileSystem = Wscript.CreateObject("Scripting.FileSystemObject")
	set settingsFile = fileSystem.OpenTextFile(SettingsFileName, 2, true)
	
	settingsFile.WriteLine "*** NCS2 DMiX Hyper-V Data ***"
	settingsFile.WriteLine "*** Date " & date & " Time " & Time() & "  ***"
	settingsFile.WriteLine "**********************************************"
	settingsFile.WriteBlankLines(1)


	'Save Hyper-V information for all Intel adapters present on the system
	
	set ncsService = GetObject("winmgmts:{impersonationLevel=impersonate}//./root/IntelNcs2")	
	ncsService.Security_.Privileges.AddAsString "SeLoadDriverPrivilege", true
	
	set physicalAdapters = ncsService.InstancesOf("IANet_PhysicalEthernetAdapter")

	for each physicalAdapter in physicalAdapters
		'Save settings for only Intel adapters by checking for Non-Intel and disabled adapters

		bIsLADIntelDevice = false

		IsIntelDevice physicalAdapter, bIsLADIntelDevice

            	if(bIsLADIntelDevice and physicalAdapter.StatusInfo = 3) then		
			SaveHyperVSettingsForPort physicalAdapter.OriginalDisplayName, settingsFile
		
			set vlanServices = ncsService.ExecQuery("ASSOCIATORS OF {" & physicalAdapter.Path_.Path & "} WHERE ResultClass = IANet_802dot1QVLANService")		
		    	for each vlanService in vlanServices		  
				set vlanAdapters = ncsService.ExecQuery("ASSOCIATORS OF {" & vlanService.Path_.Path & "} WHERE ResultClass = IANet_VLAN")
				for each vlanAdapter in vlanAdapters
					SaveHyperVSettingsForPort vlanAdapter.Caption, settingsFile
				next
		    	next			
		End if		
	next
	
	set logicalAdapters = ncsService.InstancesOf("IANet_LogicalEthernetAdapter") 

	' SCR 50668 Fix:  Without ANS installed, the IANet_LogicalEthernetAdapter class
	' Is not exposed in the WMI, causing the for each loop below to fail.  Since 
	' isNull() and isEmpty() are not reflecting when IANet_LogicalEthernetAdapter
	' is not there, it was needed to be done like this.
	on error resume next
	for each logicalAdapter in logicalAdapters
		if err.number = 0 then			
			SaveHyperVSettingsForPort logicalAdapter.Caption, settingsFile
			
			set vlanServices = ncsService.ExecQuery("ASSOCIATORS OF {" & logicalAdapter.Path_.Path & "} WHERE ResultClass = IANet_802dot1QVLANService")		
			for each vlanService in vlanServices		  
				set vlanAdapters = ncsService.ExecQuery("ASSOCIATORS OF {" & vlanService.Path_.Path & "} WHERE ResultClass = IANet_VLAN")
				for each vlanAdapter in vlanAdapters
					SaveHyperVSettingsForPort vlanAdapter.Caption, settingsFile
				next
			next
		end if
	next
	on error goto 0

	settingsFile.Close
	WScript.Echo "Hyper-V information saved!"	
end sub

'*****************************************************************************
sub SaveHyperVSettingsForPort(externalPortName, settingsFile)
	dim vsmService, switchService
	dim externalPorts, externalPort
	dim activeConnections, activeCOnnection
	dim switchPorts, switchPort
	dim deleteInParam, deleteOutParams
	dim bindInParam, bindOutParams


	'Setup WMI access
	
	set vsmService = GetObject("winmgmts:\\.\root\virtualization")
	set switchService = vsmService.ExecQuery("select * from Msvm_VirtualSwitchManagementService").ItemIndex(0)


	'Get information on virtual NIC associated with port
	
	set externalPorts = vsmService.ExecQuery("select * from Msvm_ExternalEthernetPort where ElementName = """ & externalPortName & """")
	
	for each externalPort in externalPorts
		set activeConnections = vsmService.ExecQuery("select * from Msvm_ActiveConnection")
		for each activeConnection in activeConnections
			if InStr(activeConnection.Dependent, externalPort.DeviceID) <> 0 then
				set switchPorts = vsmService.ExecQuery("select * from Msvm_SwitchPort")
				for each switchPort in switchPorts
					if InStr(activeConnection.Antecedent, switchPort.Name) <> 0 then
						
						'Write information necessary to restruct Virtual NIC association with port to the file
						
						settingsFile.WriteLine "PortName=" & externalPortName
						settingsFile.WriteLine "SystemName=" & switchPort.SystemName
						
						if InStr(switchPort.ScopeOfResidence, "") = 0 then
							settingsFile.WriteLine "ScopeOfResidence=Default"
						else
							settingsFile.WriteLine "Scope Of Residence=" & switchPort.ScopeOfResidence
						end if
						
						settingsFile.WriteBlankLines(1)
						
						
						'Delete the switchport from the virtual switch

						set deleteInParam = switchService.Methods_("DeleteSwitchPort").InParameters.SpawnInstance_()
						deleteInParam.SwitchPort = switchPort.Path_.Path

						set deleteOutParams = switchService.ExecMethod_("DeleteSwitchPort", deleteInParam)

						if deleteOutParams.ReturnValue <> 0 then
							WScript.Echo "Call to DeleteSwitchPort failed with error code " & deleteOutParams.ReturnValue
						end if

						
						'Unbind port from Hyper-V

						set bindInParam = switchService.Methods_("UnbindExternalEthernetPort").InParameters.SpawnInstance_()
						bindInParam.ExternalEthernetPort = externalPort.Path_.Path

						set bindOutParams = switchService.ExecMethod_("UnbindExternalEthernetPort", bindInParam)

						if bindOutParams.ReturnValue <> 0 then
							WScript.Echo "Call to BindExternalEthernetPort failed with error code " & bindOutParams.ReturnValue
						end if
						
						exit for
					end if
				next
				exit for
			end if
		next
	next	
end sub

'*****************************************************************************
sub RestoreHyperVSettings(settingsFileName)
	dim fileSystem, settingsFile
	dim line
	dim externalPortName, systemName, scopeOfResidence
	

	'Test whether Hyper-v is present or not
	
	on error resume next
	GetObject("winmgmts:\\.\root\virtualization")
	if err.number <> 0 then
		exit sub
	end if
	on error goto 0
	
	
	'Open input file

	set fileSystem = Wscript.CreateObject("Scripting.FileSystemObject")
	if fileSystem.FileExists(SettingsFileName) then
		set settingsFile = fileSystem.OpenTextFile(SettingsFileName, 1, false)
	else
		WScript.Echo "Hyper-v Settings files not found."
		exit sub
	end if

	
	'Read in settings for each bound port
	
	do until settingsFile.AtEndOfStream
		line = settingsFile.ReadLine
		if InStr(1,line, "PortName=", 1) <> 0 then				
			externalPortName = mid(line, 10)
			
			line = settingsFile.ReadLine
			systemName = mid(line, 12)
			
			line = settingsFile.ReadLine
			if InStr(1,line, "Default", 1) <> 0 then
				scopeOfResidence = ""
			else
				scopeOfResidence = mid(line, 18)
			end if
			
			RestoreHyperVSettingsforPort externalPortName, systemName, scopeOfResidence
		end if 
	loop
	
	settingsFile.Close
	Wscript.Echo "Finished restoring Hyper-V settings"
end sub

'*****************************************************************************
sub RestoreHyperVSettingsforPort(externalPortName, systemName, scopeOfResidence)
	dim osService
	dim osInstances, osInstance
	dim osVersion
	dim isWin2K8	
	dim vsmService, switchService
	dim externalPorts, externalPort
	dim bindInParam, bindOutParams
	dim typeLib
	dim virtualSwitch, switchPortName, switchPortFriendlyName, switchPort
	dim createInParam, createOutParams
	dim switchLANEndpoint
	dim connectInParam, connectOutParams


	'Check OS version
	
	set osService = GetObject("winmgmts:\\.\root\cimv2")
	set osInstances = osService.ExecQuery("Select * from Win32_OperatingSystem",,48)
	
	for each osInstance in osInstances
		osVersion = osInstance.Version
	next
	
	if StrComp(osVersion, "6.1") < 0 then
		isWin2K8 = true
	end if
	
	
	'Setup WMI access
	
	set vsmService = GetObject("winmgmts:\\.\root\virtualization")
	set switchService = vsmService.ExecQuery("select * from Msvm_VirtualSwitchManagementService").ItemIndex(0)


	'Find Msvm_ExternalEthernetPort associated with port specified

	set externalPorts = vsmService.ExecQuery("select * from Msvm_ExternalEthernetPort where ElementName = """ & externalPortName & """")
	for each externalPort in externalPorts
		'Bind port to Hyper-V

		set bindInParam = switchService.Methods_("BindExternalEthernetPort").InParameters.SpawnInstance_()
		bindInParam.ExternalEthernetPort = externalPort.Path_.Path

		set bindOutParams = switchService.ExecMethod_("BindExternalEthernetPort", bindInParam)

		if bindOutParams.ReturnValue <> 0 then
			WScript.Echo "Call to BindExternalEthernetPort failed with error code " & bindOutParams.ReturnValue
		end if


		'Get instances of Msvm_VirtualSwitch previously associated with VNIC

		if isWin2K8 then
			set virtualSwitch = vsmService.ExecQuery("select * from Msvm_SwitchService where Name = """ & systemName & """").ItemIndex(0)
		else
			set virtualSwitch = vsmService.ExecQuery("select * from Msvm_VirtualSwitch where Name = """ & systemName & """").ItemIndex(0)
		end if


		'Create new name and friendly name for virtual switch port

		Set typeLib = CreateObject("Scriptlet.TypeLib")
		switchPortName = typeLib.Guid

		switchPortFriendlyName = virtualSwitch.ElementName & "_ExternalPort"


		'Create a new switch port based on the old saved data
		
		set createInParam = switchService.Methods_("CreateSwitchPort").InParameters.SpawnInstance_()
		createInParam.FriendlyName = switchPortFriendlyName
		createInParam.Name = switchPortName
		if isWin2K8 then
			createInParam.SwitchService = virtualSwitch.Path_.Path
		else
			createInParam.VirtualSwitch = virtualSwitch.Path_.Path
		end if
		createInParam.ScopeofResidence = scopeOfResidence

		set createOutParams = switchService.ExecMethod_("CreateSwitchPort", createInParam)

		if createOutParams.ReturnValue = 0 then
			set switchPort = vsmService.Get(createOutParams.CreatedSwitchPort)
		else
			WScript.Echo "Call to CreateSwitchPort failed with error code " & createOutParams.ReturnValue
		end if


		'Get instances of Msvm_SwitchLANEndpoint associated with connection
		
		if isWin2K8 then
			set switchLANEndpoint = vsmService.ExecQuery("select * from Msvm_LANEndpoint where Name = ""/DEVICE/" & externalPort.DeviceID & """").ItemIndex(0)
		else
			set switchLANEndpoint = vsmService.ExecQuery("select * from Msvm_SwitchLANEndpoint where Name = ""/DEVICE/" & externalPort.DeviceID & """").ItemIndex(0)
		end if
		

		'Call ConnectSwitchPort
		
		set connectInParam = switchService.Methods_("ConnectSwitchPort").InParameters.SpawnInstance_()
		connectInParam.SwitchPort = switchPort.Path_.Path
		connectInParam.LANEndPoint = switchLANEndpoint.Path_.Path

		set connectOutParams = switchService.ExecMethod_("ConnectSwitchPort", connectInParam)

		if connectOutParams.ReturnValue <> 0 then
			WScript.Echo "Call to ConnectSwitchPort failed with error code " & connectOutParams.ReturnValue
		end if
	next
end sub
