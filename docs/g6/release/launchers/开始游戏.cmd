@echo off
setlocal enableextensions
chcp 936 >nul 2>nul
cd /d "%~dp0"
set "ROOT=%~dp0"
set "MODE=normal"
set "DRIVER="
if /i "%~1"=="--compat" (
  set "MODE=compat"
  set "DRIVER=--rendering-driver opengl3_angle"
)

rem Windows on x86_64: PROCESSOR_ARCHITECTURE=AMD64 in a 64-bit shell;
rem PROCESSOR_ARCHITEW6432=AMD64 when a 32-bit shell runs on 64-bit Windows.
set "GAME=FungusLight.exe"
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "GAME=64\FungusLight.exe"
if /i "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "GAME=64\FungusLight.exe"
if not exist "%GAME%" set "GAME=FungusLight.exe"
set "PCK=%GAME:FungusLight.exe=FungusLight.pck%"

if /i "%~1"=="--check" goto check
if /i "%~2"=="--check" goto check
goto run

:check
echo ARCH=%PROCESSOR_ARCHITECTURE% WOW=%PROCESSOR_ARCHITEW6432%
echo MODE=%MODE%
echo SELECTED=%GAME%
echo PCK=%PCK%
exit /b 0

:run
if not exist "%GAME%" goto missing_game
if not exist "%PCK%" goto missing_pck

set "LOGDIR=%LOCALAPPDATA%\FungusLight"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>nul
if not exist "%LOGDIR%" set "LOGDIR=%TEMP%"
if "%LOGDIR%"=="" set "LOGDIR=%ROOT%"
set "LOG=%LOGDIR%\startup-log.txt"
if /i "%MODE%"=="compat" set "LOG=%LOGDIR%\compat-log.txt"

echo 正在启动《菌灯之下》...
echo 程序: %GAME%
echo 日志: %LOG%
start "" /wait "%GAME%" %DRIVER% --log-file "%LOG%"
set "CODE=%ERRORLEVEL%"
if "%CODE%"=="0" goto done

if /i "%MODE%"=="compat" goto failed
echo.
echo 首次启动失败（退出码 %CODE%），正在尝试 ANGLE/D3D11 兼容模式...
set "LOG=%LOGDIR%\compat-log.txt"
start "" /wait "%GAME%" --rendering-driver opengl3_angle --log-file "%LOG%"
set "CODE=%ERRORLEVEL%"
if "%CODE%"=="0" goto done
goto failed

:missing_game
echo [错误] 找不到游戏程序：%GAME%
echo 请把 exe 与 pck 保持在同目录，并确认杀毒软件没有隔离文件。
pause
exit /b 1

:missing_pck
echo [错误] 找不到 %PCK%
echo 请把 exe 与 pck 保持在同目录，并确认杀毒软件没有隔离文件。
pause
exit /b 1

:failed
echo.
echo [提示] 游戏仍然无法启动（退出码 %CODE%）。
echo 请双击 系统检查.cmd 生成 diagnostic.txt，并把日志一起反馈。
echo 日志: %LOG%
pause
exit /b 1

:done
endlocal
