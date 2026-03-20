@echo off
setlocal

set "ENV_FILE=%~dp0.env.groq.local"
if not exist "%ENV_FILE%" (
  echo No se encontro %ENV_FILE%
  exit /b 1
)

for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
  if not "%%~A"=="" set "%%~A=%%~B"
)

if "%GROQ_CHAT_MODEL%"=="" set "GROQ_CHAT_MODEL=llama-3.3-70b-versatile"

if "%GROQ_API_KEY%"=="" (
  echo GROQ_API_KEY esta vacio en %ENV_FILE%
  exit /b 1
)

call "%~dp0flutter_safe.cmd" %* --dart-define=GROQ_API_KEY=%GROQ_API_KEY% --dart-define=GROQ_CHAT_MODEL=%GROQ_CHAT_MODEL%
