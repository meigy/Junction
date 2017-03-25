@echo off
@echo 1 install junction menu
@echo 2 remove junction menu
choice /C:12
if errorlevel 2 goto remove
if errorlevel 1 goto install
goto exit

:install
@echo start install
regsvr32 JunctionShell.dll
goto exit

:remove
@echo start remove
regsvr32 /u JunctionShell.dll
goto exit

:exit
pause
exit