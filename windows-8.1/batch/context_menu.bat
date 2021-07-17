:: Remove: Add to Library
::=================================================================================
reg delete "HKEY_CLASSES_ROOT\Folder\shellex\ContextMenuHandlers\Library Location" /f >nul 2>&1

:: Remove: Share with
::=================================================================================
::reg delete "HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers\Sharing" /f >nul 2>&1
::reg delete "HKEY_CLASSES_ROOT\Directory\Background\shellex\ContextMenuHandlers\Sharing" /f >nul 2>&1
::reg delete "HKEY_CLASSES_ROOT\Directory\shellex\ContextMenuHandlers\Sharing" /f >nul 2>&1
::reg delete "HKEY_CLASSES_ROOT\Directory\shellex\CopyHookHandlers\Sharing" /f >nul 2>&1
::reg delete "HKEY_CLASSES_ROOT\Directory\shellex\PropertySheetHandlers\Sharing" /f >nul 2>&1
::reg delete "HKEY_CLASSES_ROOT\Drive\shellex\ContextMenuHandlers\Sharing" /f >nul 2>&1
::reg delete "HKEY_CLASSES_ROOT\Drive\shellex\PropertySheetHandlers\Sharing" /f >nul 2>&1
::reg delete "HKEY_CLASSES_ROOT\LibraryFolder\background\shellex\ContextMenuHandlers\Sharing" /f >nul 2>&1
::reg delete "HKEY_CLASSES_ROOT\UserLibraryFolder\shellex\ContextMenuHandlers\Sharing" /f >nul 2>&1

EXIT