if not exist "%appdata%\Thunderbird" mkdir "%appdata%\Thunderbird"

copy "..\other\profiles.ini" "%appdata%\Thunderbird\profiles.ini" /Y

choice /d y /t 5 > nul