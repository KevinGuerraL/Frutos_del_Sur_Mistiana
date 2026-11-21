# Frutos del Sur – Instrucciones para ejecutar el .exe

## Archivos (deben estar JUNTOS en la misma carpeta)
- FrutosDelSur.exe          -> la aplicación
- ConfigurarConexion.exe    -> asistente para los datos de PostgreSQL
- config.ini                -> datos de conexión

No hace falta instalar Python. Sí hace falta acceso a la base PostgreSQL.

## Pasos
1. Copie la carpeta a la PC (por ejemplo C:\FrutosDelSur). No la ejecute desde el ZIP.
2. Abra ConfigurarConexion.exe y complete:
   - Servidor: `localhost` si PostgreSQL está en esta PC; si no, la IP del servidor
   - Puerto: normalmente 5432
   - Base de datos: nombre de la base existente (ejemplo: frutos_sur_mistiana)
   - Usuario y Contraseña de PostgreSQL (la que definió quien instaló/administra la base)
   Pulse "Guardar configuración".
3. Abra FrutosDelSur.exe.

## Restablecimiento automático de la base (IMPORTANTE)
Cada vez que se abre FrutosDelSur.exe, la app **BORRA todo el contenido de la base configurada y lo
restaura desde `frutos_sur_backup.sql`** (incluido dentro del .exe). Así cada apertura empieza limpia.
- Todo lo registrado en la sesión anterior se pierde.
- Úsela solo con una base de prueba/propia. **Nunca apunte a una base con datos reales.**
- Si dos personas usan la MISMA base, al abrir el .exe uno borra el trabajo del otro. Cada quien debe usar su propia base.
- Para desactivarlo: en `config.ini` ponga `restablecer_al_iniciar = no` en la sección `[opciones]`.
- Para usar otro respaldo sin recompilar: ponga un `frutos_sur_backup.sql` junto al .exe (tiene prioridad).
- La base debe existir (puede estar vacía); la app crea las tablas. Por seguridad no actúa sobre `postgres`.
- Si la restauración falla, la base queda como estaba y se muestra un aviso; el detalle está en `frutos_sur.log`.

## Si sale "No se pudo conectar"
- Verifique que el servicio PostgreSQL esté iniciado.
- Revise contraseña, usuario y nombre de la base (lo más común).
- Si la base está en otra PC: el firewall debe permitir el puerto 5432 y PostgreSQL
  debe aceptar conexiones remotas (postgresql.conf y pg_hba.conf).
- Revise frutos_sur.log (junto al .exe).

## Datos que genera el programa (junto al .exe)
- audit_logs\auditoria.jsonl : historial de acciones. Respáldelo.
- frutos_sur.log : errores.

## Importante
- No use setup_db.py ni schema.sql: la estructura ahora viene de frutos_sur_backup.sql.
- Si Windows muestra SmartScreen: "Más información" > "Ejecutar de todas formas".
- Si el antivirus lo bloquea, es un falso positivo común en .exe sin firmar.
