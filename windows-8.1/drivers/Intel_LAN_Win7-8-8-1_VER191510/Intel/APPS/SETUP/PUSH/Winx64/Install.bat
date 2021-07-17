@echo off

Start /wait %systemdrive%\drivers\net\INTEL\APPS\ProsetDX\Winx64\DxSetup.exe /qn /li %temp%\PROSetDX.log
goto :end

:end
REM Uncomment the next line if VLANs or Teams are to be installed.
REM Start /wait /b cscript %systemdrive%\wmiscr\SavResDX.vbs restore %systemdrive%\wmiscr\wmiconf.txt > %systemdrive%\wmiscr\output.txt

exit