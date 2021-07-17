@echo off
echo.
echo  Configuring Windows

regedit /S registry\icon_spacing.reg
echo   - Adjusted Desktop Icon Spacing

regedit /S registry\computer.reg
start .\batch\computer_links.bat
echo   - Adjusted My Computer

REM start .\Batch\context_menu.bat
REM echo   - Adjusted Context Menus

REM start .\Batch\file_endings.bat
REM echo   - Adjusted File Associations

regedit /S registry\library.reg
regedit /S registry\disable_onedrive.reg
regedit /S registry\upgrade_off.reg
echo   - Adjusted Windows Librarys

regedit /S registry\uac.reg
echo   - Turned off UAC

REM net stop HomeGroupListener >nul 2>&1
REM net stop HomeGroupProvider >nul 2>&1
REM echo   - Stopped Home Group Services

regedit /S registry\home_group.reg
echo   - Removed Home Group from Navigation

start .\tools\Setup.X86.en-US_O365HomePremRetail_21078a3b-6270-4f64-bdd7-4be712440d28_TX_DB_.exe
echo   - Started Office installation

echo   - Restarting Explorer
start .\batch\restart_explorer.bat
echo    + Started Explorer

echo.
echo  Finished all actions
echo.
choice /d y /t 5 > nul