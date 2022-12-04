setx RESTIC_REPOSITORY "G:\My Drive\Backups\Restic"
setx RESTIC_PASSWORD_FILE "D:\Windows\Path\restic.txt"
restic init
schtasks /Create /XML "..\other\task_restic_windows_folder.xml" /TN "Restic (Windows Folder)"