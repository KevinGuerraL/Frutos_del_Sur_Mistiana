"""MODELO: stock, cierre del dia (Tarea 4) y las 10 consultas del informe."""
import re

from app.db import get_cursor
from config import RESOURCE_DIR


def stock():
    with get_cursor() as cur:
        cur.execute("SELECT nombre_producto, nombre_calidad, unidad_medida, comprado, vendido, stock "
                    "FROM v_stock ORDER BY nombre_producto, nombre_calidad")
        return cur.fetchall()


def cierre_notas(fecha):
    with get_cursor() as cur:
        cur.execute("""
            SELECT np.numero_compra, c.nombre AS cliente, np.modalidad_pago,
                   SUM(COALESCE(dp.cajas::NUMERIC, dp.kilos) * dp.precio_unitario) AS total
            FROM nota_pedido np
            JOIN cliente c ON c.id_cliente = np.id_cliente
            JOIN detalle_pedido dp ON dp.numero_compra = np.numero_compra
            WHERE np.fecha = %s
            GROUP BY np.numero_compra, c.nombre, np.modalidad_pago ORDER BY np.numero_compra""", (fecha,))
        return cur.fetchall()


def cierre_compras(fecha):
    with get_cursor() as cur:
        cur.execute("""
            SELECT COALESCE(SUM(dc.cantidad * dc.precio_unitario), 0) AS total
            FROM hoja_control_compra hc JOIN detalle_compra dc ON dc.id_compra = hc.id_compra
            WHERE hc.fecha = %s""", (fecha,))
        return cur.fetchone()["total"]


def cargar_consultas():
    """Lee database/queries.sql -> [(titulo, sql)]."""
    texto = (RESOURCE_DIR / "database" / "queries.sql").read_text(encoding="utf-8")
    partes = re.split(r"^-- (Consulta \d+\. .*)$", texto, flags=re.M)
    return [(partes[i].strip(), partes[i + 1].strip()) for i in range(1, len(partes), 2)]


def ejecutar(sql):
    with get_cursor() as cur:
        cur.execute(sql)
        return cur.fetchall()
