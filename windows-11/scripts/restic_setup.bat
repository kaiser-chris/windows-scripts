setx RESTIC_REPOSITORY "G:\My Drive\Backups\Restic"
setx RESTIC_PASSWORD_FILE "D:\Windows\Path\restic.txt"
restic init
schtasks /Create /XML "..\other\task_restic_update.xml" /TN "Restic Update"
schtasks /Create /XML "..\other\task_restic_windows_folder.xml" /TN "Restic Backup (Windows Folder)"
schtasks /Create /XML "..\other\task_restic_development_folder.xml" /TN "Restic Backup (Development)"