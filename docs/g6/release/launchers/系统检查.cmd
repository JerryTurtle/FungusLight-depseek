@echo off
setlocal enableextensions
chcp 936 >nul 2>nul
cd /d "%~dp0"
set "OUT=%~dp0diagnostic.txt"
echo test> "%OUT%" 2>nul
if not exist "%OUT%" set "OUT=%TEMP%\FungusLight-diagnostic.txt"
if exist "%OUT%" del /q "%OUT%" >nul 2>nul

echo ===== 菌灯之下 诊断报告 / diagnostic report =====> "%OUT%"
echo 生成时间: %DATE% %TIME%>> "%OUT%"
echo.>> "%OUT%"
echo [系统]>> "%OUT%"
ver>> "%OUT%"
echo PROCESSOR_ARCHITECTURE=%PROCESSOR_ARCHITECTURE%>> "%OUT%"
echo PROCESSOR_ARCHITEW6432=%PROCESSOR_ARCHITEW6432%>> "%OUT%"
where powershell >nul 2>nul
if errorlevel 1 goto no_ps
powershell -NoProfile -Command "Get-WmiObject Win32_OperatingSystem | Select-Object Caption,Version,OSArchitecture | Format-List | Out-File -FilePath '%OUT%' -Append -Encoding Default" 2>nul
powershell -NoProfile -Command "Get-WmiObject Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors | Format-List | Out-File -FilePath '%OUT%' -Append -Encoding Default" 2>nul
powershell -NoProfile -Command "Get-WmiObject Win32_VideoController | Select-Object Name,DriverVersion,AdapterRAM | Format-List | Out-File -FilePath '%OUT%' -Append -Encoding Default" 2>nul
goto ps_done

:no_ps
systeminfo >> "%OUT%" 2>nul

:ps_done
echo.>> "%OUT%"
echo [游戏文件]>> "%OUT%"
for %%F in ("FungusLight.exe" "FungusLight.pck" "64\FungusLight.exe" "64\FungusLight.pck" "README.txt") do (
  if exist "%%~F" (
    dir /b "%%~F">> "%OUT%"
  ) else (
    echo 缺少: %%~F>> "%OUT%"
  )
)
echo.>> "%OUT%"
echo [启动信息 / startup info]>> "%OUT%"
for %%D in ("%APPDATA%\FungusLight" "%LOCALAPPDATA%\FungusLight" "%USERPROFILE%\Documents\FungusLight" "%~dp0用户数据") do (
  if exist "%%~D\startup-info.txt" (
    echo 位置: %%~D\startup-info.txt>> "%OUT%"
  )
)
echo.>> "%OUT%"
echo [日志文件 / logs]>> "%OUT%"
for %%L in ("%LOCALAPPDATA%\FungusLight\startup-log.txt" "%LOCALAPPDATA%\FungusLight\compat-log.txt" "%TEMP%\FungusLight-startup-log.txt") do (
  if exist "%%~L" echo 找到: %%~L>> "%OUT%"
)
echo.>> "%OUT%"
echo 请把本文件 diagnostic.txt、上面的日志文件和 startup-info.txt 一起反馈。>> "%OUT%"
type "%OUT%"
echo.
echo 诊断报告已生成: %OUT%
pause
endlocal
