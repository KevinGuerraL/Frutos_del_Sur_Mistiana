@echo off
cd /d "%~dp0"
echo ============================================
echo  Frutos del Sur - Generador de .exe
echo  Requiere Python 3 e Internet (solo la primera vez)
echo ============================================
py -m pip install --upgrade pyinstaller psycopg2-binary
if errorlevel 1 goto error

echo.
echo [1/2] Generando FrutosDelSur.exe ...
py -m PyInstaller --noconfirm --clean --onefile --windowed --name FrutosDelSur ^
  --collect-all psycopg2 --hidden-import tkinter ^
  --add-data "database;database" main.py
if errorlevel 1 goto error

echo.
echo [2/2] Generando ConfigurarConexion.exe ...
py -m PyInstaller --noconfirm --onefile --windowed --name ConfigurarConexion configurar_conexion.py
if errorlevel 1 goto error

copy /Y config.ini dist\config.ini >nul
echo.
echo LISTO. Carpeta "dist" contiene:
echo   FrutosDelSur.exe          (la aplicacion)
echo   ConfigurarConexion.exe    (asistente de conexion)
echo   config.ini                (editar con los datos de PostgreSQL)
echo Copie esos 3 archivos juntos a la PC de destino.
pause
exit /b 0
:error
echo.
echo No se pudo generar el ejecutable. Revise Python e Internet.
pause
exit /b 1
