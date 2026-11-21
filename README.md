# Frutos del Sur Mistiana — versión con interfaz simplificada

Aplicación de escritorio Python/Tkinter + PostgreSQL. Se rediseñó la navegación principal con una pantalla de bienvenida, menú lateral y tarjetas de tareas. Los módulos de operaciones existentes se conservan; no se cambia el esquema de base de datos.

## Inicio rápido en Windows
1. Extraiga el ZIP completo en una carpeta (no ejecute desde dentro del ZIP).
2. Asegúrese de tener Python 3 instalado y PostgreSQL encendido.
3. Doble clic en `CONFIGURAR_CONEXION.bat` y configure servidor, puerto, base, usuario y contraseña de la base existente.
4. Doble clic en `INICIAR.bat`. El archivo crea un entorno virtual si hace falta, instala dependencias y abre la app.

También puede ejecutar desde PowerShell: `python main.py` (en el entorno que tenga las dependencias instaladas).

## Esquema de base de datos
**No ejecutar `setup_db.py` ni scripts de reset/migración.** El proyecto se debe conectar a la base de datos existente. No se requiere modificar tablas, columnas, relaciones, restricciones ni claves para el rediseño de interfaz.

## Navegación
- Inicio: tareas en tarjetas.
- Registrar retiro: registro de retiros de campo.
- Hojas de compra: hojas de control y ajuste de precios de línea.
- Pedidos/ventas: registro y consulta de notas de pedido.
- Stock: disponibilidad.
- Cierre del día: resumen de operaciones por fecha.
- Datos y catálogos: productores, clientes, productos y calidades.
- Consultas avanzadas: consultas predefinidas del proyecto; destinadas a uso administrativo.

## Crear un ejecutable de Windows
Use `CREAR_EXE.bat` (recomendado): genera `dist\FrutosDelSur.exe` y `dist\ConfigurarConexion.exe`. Copie ambos junto con `config.ini` a la PC de destino; `config.ini`, `audit_logs` y `frutos_sur.log` se guardan junto al .exe.

Alternativa anterior:
Doble clic en `CREAR_INSTALADOR.bat`. Requiere conexión a Internet para instalar PyInstaller. El empaquetado se prepara, pero debe probarse en Windows con la conexión y la base de datos objetivo. La app requiere que PostgreSQL esté disponible.

## Estado de verificación
La revisión de esta entrega incluye cambios de interfaz y mensajes de error, comprobación de sintaxis Python y una revisión estática de la estructura. No equivale a una prueba completa con la base de datos real, ni a una validación de todos los cálculos y operaciones. Se recomienda ejecutar el checklist de auditoría adjunto antes de dar por certificada la entrega.

## Historial / auditoría de cambios

Desde el menú lateral **Historial / auditoría** se pueden consultar los eventos registrados por el aplicativo: altas, eliminaciones, generación de hojas de compra, cambios de precios y otros eventos instrumentados. Seleccione un evento y pulse **Ver detalle** para visualizar sus datos.

El historial se guarda en `audit_logs/auditoria.jsonl` junto al proyecto, separado de PostgreSQL para mantener intacto el esquema de la base de datos. Haga copia de seguridad de esa carpeta junto con los respaldos del aplicativo. Este registro es un historial de acciones de la aplicación; no sustituye un registro transaccional/audit log de PostgreSQL y no captura acciones realizadas directamente desde SQL u otras aplicaciones.

## Restablecimiento de la base al iniciar
La app restaura la base desde `database/frutos_sur_backup.sql` cada vez que se abre (borra el esquema `public` y lo recrea; operación atómica). Se controla con `restablecer_al_iniciar` en `[opciones]` de `config.ini`. Las eliminaciones usan baja lógica (`sp_baja_logica`) porque el respaldo prohíbe `DELETE` físico. Ver `INSTRUCCIONES_EXE.md`.
