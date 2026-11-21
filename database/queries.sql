-- LAS 10 CONSULTAS (version corregida). La aplicacion lee este archivo:
-- cada bloque empieza con "-- Consulta N. titulo".

-- Consulta 1. Historial de retiros con productor y procedencia
SELECT r.id_retiro, r.fecha, p.nombre AS productor, p.region_procedencia
FROM retiro_campo r
JOIN productor p ON p.id_productor = r.id_productor
ORDER BY r.fecha DESC;

-- Consulta 2. Detalle de cantidades retiradas por calidad
SELECT r.id_retiro, r.fecha, a.nombre_producto, dr.nombre_calidad, dr.cantidad, a.unidad_medida
FROM detalle_retiro dr
JOIN retiro_campo r ON r.id_retiro = dr.id_retiro
JOIN producto_agricola a ON a.cod_producto = dr.cod_producto
ORDER BY r.fecha, a.nombre_producto, dr.nombre_calidad;

-- Consulta 3. Total retirado por fecha y unidad de medida
SELECT r.fecha, a.unidad_medida, SUM(dr.cantidad) AS total_cantidad
FROM retiro_campo r
JOIN detalle_retiro dr ON dr.id_retiro = r.id_retiro
JOIN producto_agricola a ON a.cod_producto = dr.cod_producto
GROUP BY r.fecha, a.unidad_medida
ORDER BY r.fecha, a.unidad_medida;

-- Consulta 4. Total pagado al productor por hoja de control
SELECT hc.id_compra, hc.fecha,
       SUM(dc.cantidad * dc.precio_unitario) AS total_compra_soles
FROM hoja_control_compra hc
JOIN detalle_compra dc ON dc.id_compra = hc.id_compra
GROUP BY hc.id_compra, hc.fecha
ORDER BY hc.fecha;

-- Consulta 5. Compras desglosadas por producto y calidad
SELECT hc.id_compra, a.nombre_producto, dc.nombre_calidad,
       dc.cantidad, dc.precio_unitario,
       dc.cantidad * dc.precio_unitario AS subtotal_soles
FROM detalle_compra dc
JOIN hoja_control_compra hc ON hc.id_compra = dc.id_compra
JOIN producto_agricola a ON a.cod_producto = dc.cod_producto
ORDER BY hc.fecha, a.nombre_producto, dc.nombre_calidad;

-- Consulta 6. Historial de notas de pedido con datos del cliente
SELECT np.numero_compra, np.fecha, c.nombre AS cliente, c.domicilio, np.modalidad_pago
FROM nota_pedido np
JOIN cliente c ON c.id_cliente = np.id_cliente
ORDER BY np.fecha DESC;

-- Consulta 7. Detalle de productos entregados por nota de pedido
SELECT np.numero_compra, c.nombre AS cliente, a.nombre_producto,
       dp.nombre_calidad, dp.cajas, dp.kilos, dp.precio_unitario,
       COALESCE(dp.cajas::NUMERIC, dp.kilos) * dp.precio_unitario AS subtotal_soles
FROM detalle_pedido dp
JOIN nota_pedido np ON np.numero_compra = dp.numero_compra
JOIN cliente c ON c.id_cliente = np.id_cliente
JOIN producto_agricola a ON a.cod_producto = dp.cod_producto
ORDER BY np.numero_compra, a.nombre_producto;

-- Consulta 8. Importe total vendido por nota de pedido
SELECT np.numero_compra, np.fecha, c.nombre AS cliente,
       SUM(COALESCE(dp.cajas::NUMERIC, dp.kilos) * dp.precio_unitario) AS total_venta_soles
FROM nota_pedido np
JOIN cliente c ON c.id_cliente = np.id_cliente
JOIN detalle_pedido dp ON dp.numero_compra = np.numero_compra
GROUP BY np.numero_compra, np.fecha, c.nombre
ORDER BY np.fecha;

-- Consulta 9. Resumen de ventas por modalidad de pago
SELECT np.modalidad_pago,
       COUNT(DISTINCT np.numero_compra) AS cantidad_notas,
       SUM(COALESCE(dp.cajas::NUMERIC, dp.kilos) * dp.precio_unitario) AS total_soles
FROM nota_pedido np
JOIN detalle_pedido dp ON np.numero_compra = dp.numero_compra
GROUP BY np.modalidad_pago
ORDER BY np.modalidad_pago;

-- Consulta 10. Comparacion de compras y ventas por producto/calidad (stock)
SELECT nombre_producto, nombre_calidad, unidad_medida,
       comprado, vendido, stock AS diferencia
FROM v_stock
ORDER BY nombre_producto, nombre_calidad;
