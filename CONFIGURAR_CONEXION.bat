@echo off
cd /d "%~dp0"
python configurar_conexion.py
if errorlevel 1 pause
