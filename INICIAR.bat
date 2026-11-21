@echo off
cd /d "%~dp0"
if not exist "venv\Scripts\python.exe" (
 echo No se encontro entorno virtual. Preparando el entorno...
 python -m venv venv
 if errorlevel 1 goto error
)
"venv\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 goto error
"venv\Scripts\python.exe" main.py
if errorlevel 1 goto error
exit /b 0
:error
echo.
echo No se pudo iniciar. Verifique Python y PostgreSQL y revise config.ini.
pause
exit /b 1
