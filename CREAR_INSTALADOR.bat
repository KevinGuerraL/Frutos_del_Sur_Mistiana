@echo off
cd /d "%~dp0"
echo Construyendo ejecutable. Se requiere Python y acceso a Internet la primera vez.
python -m pip install pyinstaller psycopg2-binary
if errorlevel 1 goto error
python -m PyInstaller --noconfirm --clean --windowed --name FrutosDelSur --collect-all psycopg2 main.py
if errorlevel 1 goto error
echo Ejecutable generado en dist\FrutosDelSur.
pause
exit /b 0
:error
echo No se pudo generar el ejecutable. Revise Python y la conexion a Internet.
pause
exit /b 1
