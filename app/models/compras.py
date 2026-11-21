"""MODELO: hojas de control de compra (Tarea 2: Monitoreo de stock)."""
from app.db import get_cursor, next_code
from app.errors import AppError


def retiros_pendientes():
    with get_cursor() as cur:
        cur.execute("""
            SELECT r.id_retiro, r.fecha, p.nombre AS productor
            FROM retiro_campo r JOIN productor p ON p.id_productor = r.id_productor
            WHERE r.activo AND NOT EXISTS (SELECT 1 FROM hoja_control_compra h WHERE h.id_retiro = r.id_retiro)
            ORDER BY r.fecha, r.id_retiro""")
        return cur.fetchall()


def generar_hoja(id_retiro):
    """Digitaliza un retiro: copia sus lineas a detalle_compra con el precio de referencia."""
    with get_cursor() as cur:
        cur.execute("SELECT fecha FROM retiro_campo WHERE id_retiro = %s", (id_retiro,))
        r = cur.fetchone()
        if r is None:
            raise AppError("El retiro no existe.")
        codigo = next_code(cur, "hoja_control_compra", "id_compra", "HC")
        cur.execute("INSERT INTO hoja_control_compra VALUES (%s,%s,%s)", (codigo, r["fecha"], id_retiro))
        cur.execute("""
            INSERT INTO detalle_compra (id_compra, cod_producto, nombre_calidad, cantidad, precio_unitario)
            SELECT %s, d.cod_producto, d.nombre_calidad, d.cantidad, c.precio_referencia
            FROM detalle_retiro d
            JOIN calidad c ON c.cod_producto = d.cod_producto AND c.nombre_calidad = d.nombre_calidad
            WHERE d.id_retiro = %s""", (codigo, id_retiro))
        return codigo


def listar_hojas():
    with get_cursor() as cur:
        cur.execute("""
            SELECT hc.id_compra, hc.fecha, hc.id_retiro, p.nombre AS productor,
                   COALESCE(SUM(dc.cantidad) FILTER (WHERE a.unidad_medida = 'Kilogramo'), 0) AS total_kg,
                   COALESCE(SUM(dc.cantidad) FILTER (WHERE a.unidad_medida = 'Caja'), 0) AS total_cajas,
                   COALESCE(SUM(dc.cantidad * dc.precio_unitario), 0) AS total_a_pagar
            FROM hoja_control_compra hc
            JOIN retiro_campo r ON r.id_retiro = hc.id_retiro
            JOIN productor p ON p.id_productor = r.id_productor
            LEFT JOIN detalle_compra dc ON dc.id_compra = hc.id_compra
            LEFT JOIN producto_agricola a ON a.cod_producto = dc.cod_producto
            WHERE hc.activo
            GROUP BY hc.id_compra, hc.fecha, hc.id_retiro, p.nombre
            ORDER BY hc.fecha DESC, hc.id_compra DESC""")
        return cur.fetchall()


def detalle_hoja(id_compra):
    with get_cursor() as cur:
        cur.execute("""
            SELECT dc.cod_producto, a.nombre_producto, dc.nombre_calidad, dc.cantidad, a.unidad_medida,
                   dc.precio_unitario, dc.cantidad * dc.precio_unitario AS total
            FROM detalle_compra dc JOIN producto_agricola a ON a.cod_producto = dc.cod_producto
            WHERE dc.id_compra = %s ORDER BY a.nombre_producto, dc.nombre_calidad""", (id_compra,))
        return cur.fetchall()


def actualizar_precio(id_compra, cod_producto, nombre_calidad, precio):
    with get_cursor() as cur:
        cur.execute("UPDATE detalle_compra SET precio_unitario = %s "
                    "WHERE id_compra=%s AND cod_producto=%s AND nombre_calidad=%s",
                    (precio, id_compra, cod_producto, nombre_calidad))
