# Auditoría técnica inicial — Frutos del Sur Mistiana

## Alcance
Revisión del código fuente entregado, sin conexión a la base de datos productiva. La auditoría se limita a análisis estático, compilación sintáctica y pruebas unitarias aisladas de validación. No es una certificación del sistema completo.

## Protección de datos
- No se modificó el esquema SQL ni se añadieron migraciones.
- No se ejecutó setup_db.py, reset, seed ni scripts SQL sobre una base real.
- Se conservaron los módulos y la estructura de tablas existentes.

## Cambios realizados en esta versión
- Pantalla principal con navegación lateral y accesos a tareas (interfaz rediseñada existente en esta rama del proyecto).
- Mensajes de errores inesperados más claros y registro de detalle técnico en `frutos_sur.log`.
- Validación de valores numéricos finitos (rechaza NaN e Infinity), además de la validación de positivos.
- Validación de unidad en la construcción de líneas de pedido.
- Pruebas automatizadas aisladas para fechas, cantidades, datos obligatorios, cajas enteras, duplicados y unidades.

## Resultado de pruebas locales
- 12 pruebas unitarias de validación: aprobadas.
- Compilación sintáctica de los archivos Python: aprobada.
- Pruebas de conexión PostgreSQL: no realizadas (no se dispone de la instancia y credenciales de la empresa en esta auditoría).
- Pruebas de operaciones CRUD con datos reales: pendientes.
- Pruebas de instalación en otro Windows: pendientes.
- Generación y ejecución de EXE: pendientes.

## Riesgos / pendientes que requieren validación de negocio y base real
1. Correlativos calculados con MAX de identificadores (retiros, productores, clientes, productos): concurrencia de usuarios podría generar colisión. Corregirlo sin modificar el esquema requeriría acordar una estrategia compatible con las restricciones existentes.
2. Conversión de cajas y kilos y unidades usadas en precios: verificar casos de productos cuya unidad base sea Caja y Kilogramo, con datos reales y reglas comerciales confirmadas.
3. El stock se lee desde la vista `v_stock`; probar ventas consecutivas, transacciones y stock insuficiente con datos de prueba respaldados.
4. Eliminar retiros/notas que tienen relaciones: validar mensajes y reglas de negocio en PostgreSQL.
5. Cierre diario: confirmar si el total de compra debe representar costo registrado por hoja de compra y si las fechas corresponden a las reglas operativas.
6. Consultas predefinidas: comprobar que todas las 10 consultas respondan con el conjunto real de datos y que sus resultados sean correctos.
7. Empaquetado PyInstaller: comprobar el EXE en Windows limpio y verificar rutas de config.ini, registro de errores y dependencia de PostgreSQL.

## Checklist de aceptación para completar el 100% funcional
- [ ] Inicio de sesión/conexión a la base existente con usuario autorizado.
- [ ] Registrar, consultar, detallar y eliminar (cuando corresponda) retiro.
- [ ] Crear hoja de control desde un retiro y modificar precio de línea.
- [ ] Registrar pedido Contado y Crédito; comprobar firma opcional.
- [ ] Comprobar stock, conversión caja/kilo, stock insuficiente y duplicidad de líneas.
- [ ] Consultar stock antes y después de operaciones.
- [ ] Cierre del día: compras, ventas contado, ventas crédito y notas.
- [ ] CRUD de catálogos (productores, clientes, productos, calidades), restricciones y mensajes.
- [ ] Ejecutar las 10 consultas predefinidas.
- [ ] Pruebas de errores, fechas, cantidades, duplicados y confirmación de eliminaciones.
- [ ] Instalar y ejecutar en otra computadora Windows sin ambiente de desarrollo.
- [ ] Generar y probar EXE; comprobar acceso a config y log.
- [ ] Confirmar por inspección y hash que el esquema SQL no ha cambiado.

## Conclusión
Esta entrega contiene correcciones concretas de validación, registro de errores y pruebas automatizadas, además del rediseño de navegación presente en el código. No puede declararse 100% completa hasta ejecutar el checklist con la base de datos y ambiente real, porque esas pruebas no se pueden simular con certeza mediante análisis estático.
