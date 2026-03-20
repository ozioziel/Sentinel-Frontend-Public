@echo off
setlocal

if defined FLUTTER_ROOT (
  if exist "%FLUTTER_ROOT%\bin\flutter.bat" (
    call "%FLUTTER_ROOT%\bin\flutter.bat" %*
    exit /b %ERRORLEVEL%
  )
)

where flutter >nul 2>nul
if %ERRORLEVEL% EQU 0 (
  call flutter %*
  exit /b %ERRORLEVEL%
)

echo No se encontro Flutter.
echo.
echo Opciones:
echo 1. Agrega Flutter al PATH y vuelve a ejecutar este comando.
echo 2. O define la variable de entorno FLUTTER_ROOT apuntando al SDK de Flutter.
echo.
echo Ejemplo en PowerShell:
echo   $env:FLUTTER_ROOT="C:\src\flutter"
echo.
exit /b 1
