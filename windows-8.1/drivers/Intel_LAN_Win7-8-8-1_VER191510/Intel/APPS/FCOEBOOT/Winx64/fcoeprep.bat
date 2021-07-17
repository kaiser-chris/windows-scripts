@echo off
rem FCoE Image Prep batch file

rem Ask user for permission to continue.
echo.
echo Intel(R) FCoE Image Prep
echo.
echo This script will prepare the currently running copy of
echo Windows for imaging to an FCoE disk.
set /p choice=DO YOU WANT TO CONTINUE (Y/N)?
if "%choice%"=="" goto BadChoic
if /i "%choice%"=="y" goto PrepImg
if /i "%choice%"=="n" goto ChoiceN
goto BadChoic

:PrepImg

echo.

rem If this is not Windows Server 2008 skip bcdedit.
ver | find "Version 6.0" > nul
if errorlevel 1 goto SkipBcd

bcdedit /set {current} device boot
if errorlevel 1 goto BcdFail
bcdedit /set {current} osdevice boot
if errorlevel 1 goto BcdFail
echo Successfully set BCD data for FCoE boot.

:SkipBcd

FcoeImagePrep p
if errorlevel 1 goto FIPFail
goto GoodExit

:BcdFail
echo Failed to set BCD data.
goto ErrExit

:FIPFail
echo FCoE Image Prep failed to prepare Windows.
goto ErrExit

:BadChoic
echo Invalid choice - script terminating.
goto ErrExit

:ChoiceN
echo You chose not to prepare Windows for imaging to an FCoE disk.
goto ErrExit

:ErrExit
echo Windows was not prepared for imaging to FCoE disk.
goto End

:GoodExit
echo Windows was successfully prepared for imaging to FCoE disk.
goto End

:End
