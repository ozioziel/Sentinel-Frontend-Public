@echo off
setlocal
setlocal EnableDelayedExpansion

set "ENV_FILE=%~dp0.env.groq.local"
set "EXTRA_DEFINES="
set "FLUTTER_COMMAND=%~1"

if not exist "%ENV_FILE%" (
  echo No se encontro %ENV_FILE%
  echo Crea tu archivo local a partir de .env.groq.example
  exit /b 1
)

for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
  set "ENV_KEY=%%~A"
  if not "!ENV_KEY!"=="" if not "!ENV_KEY:~0,1!"=="#" set "%%~A=%%~B"
)

if "%GROQ_CHAT_MODEL%"=="" set "GROQ_CHAT_MODEL=llama-3.3-70b-versatile"

if "%GROQ_API_KEY%"=="" (
  echo GROQ_API_KEY esta vacio en %ENV_FILE%
  exit /b 1
)

set "EXTRA_DEFINES=%EXTRA_DEFINES% --dart-define=GROQ_API_KEY=%GROQ_API_KEY%"
set "EXTRA_DEFINES=%EXTRA_DEFINES% --dart-define=GROQ_CHAT_MODEL=%GROQ_CHAT_MODEL%"

if not "%BACKEND_URL%"=="" (
  set "EXTRA_DEFINES=%EXTRA_DEFINES% --dart-define=BACKEND_URL=%BACKEND_URL%"
)

if not "%GROQ_API_BASE_URL%"=="" (
  set "EXTRA_DEFINES=%EXTRA_DEFINES% --dart-define=GROQ_API_BASE_URL=%GROQ_API_BASE_URL%"
)

if /I "%FLUTTER_COMMAND%"=="run" (
  call "%~dp0flutter_safe.cmd" %* %EXTRA_DEFINES%
  exit /b %ERRORLEVEL%
)

if /I "%FLUTTER_COMMAND%"=="build" (
  call "%~dp0flutter_safe.cmd" %* %EXTRA_DEFINES%
  exit /b %ERRORLEVEL%
)

if /I "%FLUTTER_COMMAND%"=="test" (
  call "%~dp0flutter_safe.cmd" %* %EXTRA_DEFINES%
  exit /b %ERRORLEVEL%
)

call "%~dp0flutter_safe.cmd" %*
