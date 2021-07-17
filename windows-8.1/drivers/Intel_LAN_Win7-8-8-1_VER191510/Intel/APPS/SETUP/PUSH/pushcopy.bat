@echo off
rem *******************************************************************************
rem Make sure we are in the right directory
rem *******************************************************************************
if NOT exist .\PUSHCOPY.BAT GOTO WRONGDIR


rem *******************************************************************************
rem %1 = Destination Path
rem %2 = OS
rem *******************************************************************************

if /I "%2"=="WIN732" goto WIN732
if /I "%2"=="WIN7X64" goto WIN7X64
if /I "%2"=="WS08R2X64" goto WIN7X64
if /I "%2"=="WIN832" goto WIN832
if /I "%2"=="WIN8X64" goto WIN8X64
if /I "%2"=="WIN8.132" goto WIN8.132
if /I "%2"=="WIN8.1X64" goto WIN8.1X64

goto Usage

rem *******************************************************************************
rem 	WINDOWS 7/2K8 R2/Windows 8 client 32 file copies
rem *******************************************************************************
:WIN732
echo *** Windows 7, Windows Server 2008 R2 and Windows 8 client 32 file copy
rem *******************************************************************************
rem Create the OEM driver directory structure
rem *******************************************************************************
md %1\$oem$
md %1\$oem$\$$
md %1\$oem$\$$\system32
md %1\$oem$\$1
md %1\$oem$\$1\WMIScr
md %1\$oem$\$1\drivers
md %1\$oem$\$1\drivers\net
md %1\$oem$\$1\drivers\net\INTEL
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM
md %1\$oem$\$1\drivers\net\INTEL\APPS
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Win32
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Win32\Drivers
md %1\$oem$\$1\drivers\net\INTEL\APPS\Tools
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup\SetupBD
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup\SetupBD\Win32
md %1\$oem$\$1\drivers\net\INTEL\PRO1000
md %1\$oem$\$1\drivers\net\INTEL\PRO1000\Win32
md %1\$oem$\$1\drivers\net\INTEL\PRO1000\Win32\NDIS62

REM **********************************************************************
REM  COPY Base driver files for Windows 7
REM **********************************************************************

rem Gigabit specific files
copy ..\..\..\PRO1000\Win32\NDIS62\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\PRO1000\Win32\NDIS62

rem *******************************************************************************
rem Copy the PROSet DX files
rem *******************************************************************************
copy ..\..\PROSetDX\Win32\*.* %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Win32

rem *******************************************************************************
rem Copy the ANS files
rem *******************************************************************************
copy ..\..\PROSetDX\Win32\DRIVERS\*.* %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Win32\Drivers

rem *******************************************************************************
rem Copy the SetupBD files
rem *******************************************************************************
copy ..\..\SETUP\SETUPBD\Win32\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\APPS\Setup\SetupBD\Win32

rem *******************************************************************************
rem Copy the Tools files
rem *******************************************************************************
copy ..\..\Tools\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\APPS\Tools

REM *******************************************************************************
REM Copy the Intel Active Management Technology drivers and Serial Over Lan drivers if available
REM *******************************************************************************
if not exist ..\..\..\PLATFORM\INTELAMT\DRIVERS\Win32 goto end
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS\Win32
copy ..\..\..\PLATFORM\INTELAMT\DRIVERS\Win32\*.*  %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS\Win32

REM *******************************************************************************
REM Copy the Intel I/O Acceleration Technology drivers
REM *******************************************************************************
if not exist ..\..\..\PLATFORM\IOATDMA\Win32 goto end
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Win32
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Win32\NDIS62
copy /v ..\..\..\PLATFORM\IOATDMA\Win32\NDIS62\qd* %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Win32\NDIS62

rem *******************************************************************************
rem Copy the sample Install.bat and help file
rem *******************************************************************************
copy Win32\Install.bat %1\$oem$\$1\WMIScr
copy Win32\push32.txt %1\$oem$\$1\drivers\net\INTEL

goto end

rem *******************************************************************************
rem 	WINDOWS 7/2K8 R2/WINDOWS 8 Client/WINDOWS 8 SERVER 32e file copies
rem *******************************************************************************
:WIN7X64
echo *** Windows 7, Windows Server 2008 R2, Windows 8 Client and Windows 8 Server 32e file copy
rem *******************************************************************************
rem Create the OEM driver directory structure
rem *******************************************************************************
md %1\$oem$
md %1\$oem$\$$
md %1\$oem$\$$\system32
md %1\$oem$\$1
md %1\$oem$\$1\WMIScr
md %1\$oem$\$1\drivers
md %1\$oem$\$1\drivers\net
md %1\$oem$\$1\drivers\net\INTEL
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM
md %1\$oem$\$1\drivers\net\INTEL\APPS
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Winx64
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Winx64\Drivers
md %1\$oem$\$1\drivers\net\INTEL\APPS\Tools
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup\SetupBD
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup\SetupBD\Winx64
md %1\$oem$\$1\drivers\net\INTEL\PRO1000
md %1\$oem$\$1\drivers\net\INTEL\PRO1000\Winx64
md %1\$oem$\$1\drivers\net\INTEL\PRO1000\Winx64\NDIS62

REM **********************************************************************
REM  COPY Base driver files for Windows 7
REM **********************************************************************

rem Gigabit specific files
copy ..\..\..\PRO1000\Winx64\NDIS62\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\PRO1000\Winx64\NDIS62

rem *******************************************************************************
rem Copy the PROSet DX files
rem *******************************************************************************
copy ..\..\PROSetDX\Winx64\*.* %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Winx64

rem *******************************************************************************
rem Copy the ANS files
rem *******************************************************************************
copy ..\..\PROSetDX\Winx64\DRIVERS\*.* %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Winx64\Drivers

rem *******************************************************************************
rem Copy the SetupBD files
rem *******************************************************************************
copy ..\..\SETUP\SETUPBD\Winx64\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\APPS\Setup\SetupBD\Winx64

rem *******************************************************************************
rem Copy the Tools files
rem *******************************************************************************
copy ..\..\Tools\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\APPS\Tools

REM *******************************************************************************
REM Copy the Intel Active Management Technology drivers and Serial Over Lan drivers if avialable
REM *******************************************************************************
if not exist ..\..\..\PLATFORM\INTELAMT\DRIVERS\Winx64 goto end
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS\Winx64
copy ..\..\..\PLATFORM\INTELAMT\DRIVERS\Winx64\*.*  %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS\Winx64

REM *******************************************************************************
REM Copy the Intel I/O Acceleration Technology drivers
REM *******************************************************************************
if not exist ..\..\..\PLATFORM\IOATDMA\Winx64 goto end
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Winx64
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Winx64\NDIS62
copy /Y ..\..\..\PLATFORM\IOATDMA\Winx64\NDIS62\*.DLL %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Winx64\NDIS62
copy /Y ..\..\..\PLATFORM\IOATDMA\Winx64\NDIS62\*62*.* %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Winx64\NDIS62
copy /Y ..\..\..\PLATFORM\IOATDMA\Winx64\NDIS62\qd3nodrv.* %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Winx64\NDIS62

rem *******************************************************************************
rem Copy the sample Install.bat and help file
rem *******************************************************************************
copy Winx64\Install.bat %1\$oem$\$1\WMIScr
copy Winx64\pushx64.txt %1\$oem$\$1\drivers\net\INTEL

rem *******************************************************************************
rem Copy the Win7-specific or Windows Server 2008 R2-specific files
rem *******************************************************************************
if /I "%2"=="WS08R2X64" goto WS08R2X64
goto end

:WS08R2X64
goto end

rem *******************************************************************************
rem 	WINDOWS client 32 file copies
rem *******************************************************************************
:WIN832
echo *** Windows 8 client 32 file copy
rem *******************************************************************************
rem Create the OEM driver directory structure
rem *******************************************************************************
md %1\$oem$
md %1\$oem$\$$
md %1\$oem$\$$\system32
md %1\$oem$\$1
md %1\$oem$\$1\WMIScr
md %1\$oem$\$1\drivers
md %1\$oem$\$1\drivers\net
md %1\$oem$\$1\drivers\net\INTEL
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM
md %1\$oem$\$1\drivers\net\INTEL\APPS
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Win32
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Win32\Drivers
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Win32\Drivers\Win8
md %1\$oem$\$1\drivers\net\INTEL\APPS\Tools
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup\SetupBD
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup\SetupBD\Win32
md %1\$oem$\$1\drivers\net\INTEL\PRO1000
md %1\$oem$\$1\drivers\net\INTEL\PRO1000\Win32
md %1\$oem$\$1\drivers\net\INTEL\PRO1000\Win32\NDIS63

REM **********************************************************************
REM  COPY Base driver files for Windows 8 client
REM **********************************************************************

rem Gigabit specific files
copy ..\..\..\PRO1000\Win32\NDIS63\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\PRO1000\Win32\NDIS63

rem *******************************************************************************
rem Copy the PROSet DX files
rem *******************************************************************************
copy ..\..\PROSetDX\Win32\*.* %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Win32

rem *******************************************************************************
rem Copy the ANS files
rem *******************************************************************************
copy ..\..\PROSetDX\Win32\DRIVERS\*.* %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Win32\Drivers
copy ..\..\PROSetDX\Win32\DRIVERS\Win8\*.* %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Win32\Drivers\win8

rem *******************************************************************************
rem Copy the SetupBD files
rem *******************************************************************************
copy ..\..\SETUP\SETUPBD\Win32\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\APPS\Setup\SetupBD\Win32

rem *******************************************************************************
rem Copy the Tools files
rem *******************************************************************************
copy ..\..\Tools\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\APPS\Tools

REM *******************************************************************************
REM Copy the Intel Active Management Technology drivers and Serial Over Lan drivers if available
REM *******************************************************************************
if not exist ..\..\..\PLATFORM\INTELAMT\DRIVERS\Win32 goto end
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS\Win32
copy ..\..\..\PLATFORM\INTELAMT\DRIVERS\Win32\*.*  %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS\Win32

REM *******************************************************************************
REM Copy the Intel I/O Acceleration Technology drivers
REM *******************************************************************************
if not exist ..\..\..\PLATFORM\IOATDMA\Win32 goto end
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Win32
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Win32\NDIS62
copy /v ..\..\..\PLATFORM\IOATDMA\Win32\NDIS62\qd* %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Win32\NDIS62

rem *******************************************************************************
rem Copy the sample Install.bat and help file
rem *******************************************************************************
copy Win32\Install.bat %1\$oem$\$1\WMIScr
copy Win32\push32.txt %1\$oem$\$1\drivers\net\INTEL

goto end

rem *******************************************************************************
rem 	WINDOWS 8 Client/WINDOWS 8 SERVER 32e file copies
rem *******************************************************************************
:WIN8X64
echo *** Windows 8 Client and Windows 8 Server 32e file copy
rem *******************************************************************************
rem Create the OEM driver directory structure
rem *******************************************************************************
md %1\$oem$
md %1\$oem$\$$
md %1\$oem$\$$\system32
md %1\$oem$\$1
md %1\$oem$\$1\WMIScr
md %1\$oem$\$1\drivers
md %1\$oem$\$1\drivers\net
md %1\$oem$\$1\drivers\net\INTEL
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM
md %1\$oem$\$1\drivers\net\INTEL\APPS
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Winx64
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Winx64\Drivers
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Winx64\Drivers\Win8
md %1\$oem$\$1\drivers\net\INTEL\APPS\Tools
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup\SetupBD
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup\SetupBD\Winx64
md %1\$oem$\$1\drivers\net\INTEL\PRO1000
md %1\$oem$\$1\drivers\net\INTEL\PRO1000\Winx64
md %1\$oem$\$1\drivers\net\INTEL\PRO1000\Winx64\NDIS63

REM **********************************************************************
REM  COPY Base driver files for Windows 8
REM **********************************************************************

rem Gigabit specific files
copy ..\..\..\PRO1000\Winx64\NDIS63\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\PRO1000\Winx64\NDIS63

rem *******************************************************************************
rem Copy the PROSet DX files
rem *******************************************************************************
copy ..\..\PROSetDX\Winx64\*.* %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Winx64

rem *******************************************************************************
rem Copy the ANS files
rem *******************************************************************************
copy ..\..\PROSetDX\Winx64\DRIVERS\*.* %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Winx64\Drivers
copy ..\..\PROSetDX\Winx64\DRIVERS\Win8\*.* %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Winx64\Drivers\Win8

rem *******************************************************************************
rem Copy the SetupBD files
rem *******************************************************************************
copy ..\..\SETUP\SETUPBD\Winx64\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\APPS\Setup\SetupBD\Winx64

rem *******************************************************************************
rem Copy the Tools files
rem *******************************************************************************
copy ..\..\Tools\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\APPS\Tools

REM *******************************************************************************
REM Copy the Intel Active Management Technology drivers and Serial Over Lan drivers if avialable
REM *******************************************************************************
if not exist ..\..\..\PLATFORM\INTELAMT\DRIVERS\Winx64 goto end
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS\Winx64
copy ..\..\..\PLATFORM\INTELAMT\DRIVERS\Winx64\*.*  %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS\Winx64

REM *******************************************************************************
REM Copy the Intel I/O Acceleration Technology drivers
REM *******************************************************************************
if not exist ..\..\..\PLATFORM\IOATDMA\Winx64 goto end
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Winx64
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Winx64\NDIS62
copy /Y ..\..\..\PLATFORM\IOATDMA\Winx64\NDIS62\*.DLL %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Winx64\NDIS62
copy /Y ..\..\..\PLATFORM\IOATDMA\Winx64\NDIS62\*62*.* %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Winx64\NDIS62
copy /Y ..\..\..\PLATFORM\IOATDMA\Winx64\NDIS62\qd3nodrv.* %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Winx64\NDIS62

rem *******************************************************************************
rem Copy the sample Install.bat and help file
rem *******************************************************************************
copy Winx64\Install.bat %1\$oem$\$1\WMIScr
copy Winx64\pushx64.txt %1\$oem$\$1\drivers\net\INTEL

goto end

rem *******************************************************************************
rem 	WINDOWS client 32 file copies
rem *******************************************************************************
:WIN8.132
echo *** Windows 8.1 client 32 file copy
rem *******************************************************************************
rem Create the OEM driver directory structure
rem *******************************************************************************
md %1\$oem$
md %1\$oem$\$$
md %1\$oem$\$$\system32
md %1\$oem$\$1
md %1\$oem$\$1\WMIScr
md %1\$oem$\$1\drivers
md %1\$oem$\$1\drivers\net
md %1\$oem$\$1\drivers\net\INTEL
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM
md %1\$oem$\$1\drivers\net\INTEL\APPS
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Win32
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Win32\Drivers
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Win32\Drivers\Win8
md %1\$oem$\$1\drivers\net\INTEL\APPS\Tools
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup\SetupBD
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup\SetupBD\Win32
md %1\$oem$\$1\drivers\net\INTEL\PRO1000
md %1\$oem$\$1\drivers\net\INTEL\PRO1000\Win32
md %1\$oem$\$1\drivers\net\INTEL\PRO1000\Win32\NDIS64

REM **********************************************************************
REM  COPY Base driver files for Windows 8 client
REM **********************************************************************

rem Gigabit specific files
copy ..\..\..\PRO1000\Win32\NDIS64\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\PRO1000\Win32\NDIS64

rem *******************************************************************************
rem Copy the PROSet DX files
rem *******************************************************************************
copy ..\..\PROSetDX\Win32\*.* %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Win32

rem *******************************************************************************
rem Copy the ANS files
rem *******************************************************************************
copy ..\..\PROSetDX\Win32\DRIVERS\*.* %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Win32\Drivers
copy ..\..\PROSetDX\Win32\DRIVERS\Win8\*.* %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Win32\Drivers\win8

rem *******************************************************************************
rem Copy the SetupBD files
rem *******************************************************************************
copy ..\..\SETUP\SETUPBD\Win32\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\APPS\Setup\SetupBD\Win32

rem *******************************************************************************
rem Copy the Tools files
rem *******************************************************************************
copy ..\..\Tools\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\APPS\Tools

REM *******************************************************************************
REM Copy the Intel Active Management Technology drivers and Serial Over Lan drivers if available
REM *******************************************************************************
if not exist ..\..\..\PLATFORM\INTELAMT\DRIVERS\Win32 goto end
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS\Win32
copy ..\..\..\PLATFORM\INTELAMT\DRIVERS\Win32\*.*  %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS\Win32

REM *******************************************************************************
REM Copy the Intel I/O Acceleration Technology drivers
REM *******************************************************************************
if not exist ..\..\..\PLATFORM\IOATDMA\Win32 goto end
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Win32
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Win32\NDIS62
copy /v ..\..\..\PLATFORM\IOATDMA\Win32\NDIS62\qd* %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Win32\NDIS62

rem *******************************************************************************
rem Copy the sample Install.bat and help file
rem *******************************************************************************
copy Win32\Install.bat %1\$oem$\$1\WMIScr
copy Win32\push32.txt %1\$oem$\$1\drivers\net\INTEL

goto end

rem *******************************************************************************
rem 	WINDOWS 8.1 Client/WINDOWS 8.1 SERVER 32e file copies
rem *******************************************************************************
:WIN8.1X64
echo *** Windows 8.1 Client and Windows 8.1 Server 32e file copy
rem *******************************************************************************
rem Create the OEM driver directory structure
rem *******************************************************************************
md %1\$oem$
md %1\$oem$\$$
md %1\$oem$\$$\system32
md %1\$oem$\$1
md %1\$oem$\$1\WMIScr
md %1\$oem$\$1\drivers
md %1\$oem$\$1\drivers\net
md %1\$oem$\$1\drivers\net\INTEL
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM
md %1\$oem$\$1\drivers\net\INTEL\APPS
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Winx64
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Winx64\Drivers
md %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Winx64\Drivers\Win8
md %1\$oem$\$1\drivers\net\INTEL\APPS\Tools
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup\SetupBD
md %1\$oem$\$1\drivers\net\INTEL\APPS\Setup\SetupBD\Winx64
md %1\$oem$\$1\drivers\net\INTEL\PRO1000
md %1\$oem$\$1\drivers\net\INTEL\PRO1000\Winx64
md %1\$oem$\$1\drivers\net\INTEL\PRO1000\Winx64\NDIS64

REM **********************************************************************
REM  COPY Base driver files for Windows 8
REM **********************************************************************

rem Gigabit specific files
copy ..\..\..\PRO1000\Winx64\NDIS64\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\PRO1000\Winx64\NDIS64

rem *******************************************************************************
rem Copy the PROSet DX files
rem *******************************************************************************
copy ..\..\PROSetDX\Winx64\*.* %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Winx64

rem *******************************************************************************
rem Copy the ANS files
rem *******************************************************************************
copy ..\..\PROSetDX\Winx64\DRIVERS\*.* %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Winx64\Drivers
copy ..\..\PROSetDX\Winx64\DRIVERS\Win8\*.* %1\$oem$\$1\drivers\net\INTEL\APPS\ProsetDX\Winx64\Drivers\Win8

rem *******************************************************************************
rem Copy the SetupBD files
rem *******************************************************************************
copy ..\..\SETUP\SETUPBD\Winx64\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\APPS\Setup\SetupBD\Winx64

rem *******************************************************************************
rem Copy the Tools files
rem *******************************************************************************
copy ..\..\Tools\*.* %1\$OEM$\$1\DRIVERS\NET\INTEL\APPS\Tools

REM *******************************************************************************
REM Copy the Intel Active Management Technology drivers and Serial Over Lan drivers if avialable
REM *******************************************************************************
if not exist ..\..\..\PLATFORM\INTELAMT\DRIVERS\Winx64 goto end
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS\Winx64
copy ..\..\..\PLATFORM\INTELAMT\DRIVERS\Winx64\*.*  %1\$oem$\$1\drivers\net\INTEL\PLATFORM\INTELAMT\DRIVERS\Winx64

REM *******************************************************************************
REM Copy the Intel I/O Acceleration Technology drivers
REM *******************************************************************************
if not exist ..\..\..\PLATFORM\IOATDMA\Winx64 goto end
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Winx64
md %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Winx64\NDIS62
copy /Y ..\..\..\PLATFORM\IOATDMA\Winx64\NDIS62\*.DLL %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Winx64\NDIS62
copy /Y ..\..\..\PLATFORM\IOATDMA\Winx64\NDIS62\*62*.* %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Winx64\NDIS62
copy /Y ..\..\..\PLATFORM\IOATDMA\Winx64\NDIS62\qd3nodrv.* %1\$oem$\$1\drivers\net\INTEL\PLATFORM\IOATDMA\Winx64\NDIS62

rem *******************************************************************************
rem Copy the sample Install.bat and help file
rem *******************************************************************************
copy Winx64\Install.bat %1\$oem$\$1\WMIScr
copy Winx64\pushx64.txt %1\$oem$\$1\drivers\net\INTEL

goto end

rem *******************************************************************************
rem 	Error Cases
rem *******************************************************************************

:WRONGDIR
echo.
echo.
echo PUSHCOPY must be run from the \APPS\SETUP\PUSH directory on the CD or 
echo CD image to work properly.  
echo.
echo  Please change directories to the \APPS\SETUP\PUSH directory before running PUSHCOPY.
echo.
echo.


:Usage
echo.
echo Invalid Command Line Argument
echo.
echo Usage Rules:
echo pushcopy [Destination Path] [OS]
echo where [destination] is the drive letter and path (such as Z:)
echo       Do not add a trailing backslash (\) to the destination path. 
echo [OS]    	= OS family
echo WIN732		= Microsoft Windows 7* 32 bit
echo WIN7X64		= Microsoft Windows 7* x64
echo WS08R2X64	= Microsoft Windows Server 2008 R2* x64
echo WIN832          = Microsoft Windows 8 Client* 32 bit
echo WIN8X64         = Microsoft Windows 8 Client and Server* x64
echo WIN8.132        = Microsoft Windows 8.1 Client* 32 bit
echo WIN8.1X64       = Microsoft Windows 8.1 Client and Server* x64

echo.

:end
