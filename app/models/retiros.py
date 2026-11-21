"""MODELO: retiros de campo (Tarea 1: Registro de retiro)."""
import psycopg2.errors as pgerr

from app.db import baja_logica, get_cursor, next_code
from app.errors import AppError

DIAS = {0: "Lunes", 3: "Jueves", 5: "Sábado"}   # date.weekday()


def listar():
    with get_cursor() as cur:
        cur.execute("""
            SELECT r.id_retiro, r.fecha, c.dia_semana, p.nombre AS productor, p.region_procedencia,
                   (hc.id_compra IS NOT NULL) AS con_hoja_de_control
            FROM retiro_campo r
            JOIN calendario_retiro c ON c.fecha = r.fecha
            JOIN productor p ON p.id_productor = r.id_productor
            LEFT JOIN hoja_control_compra hc ON hc.id_retiro = r.id_retiro AND hc.activo
            WHERE r.activo
            ORDER BY r.fecha DESC, r.id_retiro DESC""")
        return cur.fetchall()


def detalle(id_retiro):
    with get_cursor() as cur:
        cur.execute("""
            SELECT a.nombre_producto, d.nombre_calidad, d.cantidad, a.unidad_medida
            FROM detalle_retiro d JOIN producto_agricola a ON a.cod_producto = d.cod_producto
            WHERE d.id_retiro = %s ORDER BY a.nombre_producto, d.nombre_calidad""", (id_retiro,))
        return cur.fetchall()


def crear(fecha, id_productor, lineas):
    """lineas = [{'cod_producto','nombre_calidad','cantidad'}, ...]. Todo en una transaccion."""
    if fecha.weekday() not in DIAS:
        raise AppError("Los retiros solo se realizan lunes, jueves y sábado.")
    with get_cursor() as cur:
        cur.execute("INSERT INTO calendario_retiro VALUES (%s,%s) ON CONFLICT (fecha) DO NOTHING",
                    (fecha, DIAS[fecha.weekday()]))
        codigo = next_code(cur, "retiro_campo", "id_retiro", "RET")
        cur.execute("INSERT INTO retiro_campo VALUES (%s,%s,%s)", (codigo, fecha, id_productor))
        for l in lineas:
            cur.execute("INSERT INTO detalle_retiro VALUES (%s,%s,%s,%s)",
                        (codigo, l["cod_producto"], l["nombre_calidad"], l["cantidad"]))
        return codigo


def eliminar(id_retiro):
    baja_logica("retiro_campo", id_retiro)
