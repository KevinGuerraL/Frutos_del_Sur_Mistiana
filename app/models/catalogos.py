"""MODELO: productores, clientes, productos y calidades."""
import psycopg2.errors as pgerr

from app.db import baja_logica, get_cursor, next_code
from app.errors import AppError


def listar_productores():
    with get_cursor() as cur:
        cur.execute("SELECT id_productor, nombre, region_procedencia FROM productor WHERE activo ORDER BY id_productor")
        return cur.fetchall()


def crear_productor(nombre, region):
    with get_cursor() as cur:
        codigo = next_code(cur, "productor", "id_productor", "PR")
        cur.execute("INSERT INTO productor VALUES (%s,%s,%s)", (codigo, nombre, region))
        return codigo


def listar_clientes():
    with get_cursor() as cur:
        cur.execute("SELECT id_cliente, nombre, domicilio, telefono FROM cliente WHERE activo ORDER BY id_cliente")
        return cur.fetchall()


def crear_cliente(nombre, domicilio, telefono):
    with get_cursor() as cur:
        codigo = next_code(cur, "cliente", "id_cliente", "CL")
        cur.execute("INSERT INTO cliente VALUES (%s,%s,%s,%s)", (codigo, nombre, domicilio, telefono))
        return codigo


def listar_productos():
    with get_cursor() as cur:
        cur.execute("SELECT cod_producto, nombre_producto, unidad_medida, kg_por_caja "
                    "FROM producto_agricola WHERE activo ORDER BY cod_producto")
        return cur.fetchall()


def crear_producto(nombre, unidad, kg_por_caja):
    with get_cursor() as cur:
        codigo = next_code(cur, "producto_agricola", "cod_producto", "PA", 2)
        cur.execute("INSERT INTO producto_agricola VALUES (%s,%s,%s,%s)",
                    (codigo, nombre, unidad, kg_por_caja))
        return codigo


def listar_calidades(cod_producto=None):
    with get_cursor() as cur:
        if cod_producto:
            cur.execute("SELECT cod_producto, nombre_calidad, precio_referencia FROM calidad "
                        "WHERE cod_producto=%s AND activo ORDER BY precio_referencia DESC", (cod_producto,))
        else:
            cur.execute("SELECT cod_producto, nombre_calidad, precio_referencia FROM calidad "
                        "WHERE activo ORDER BY cod_producto, precio_referencia DESC")
        return cur.fetchall()


def guardar_calidad(cod_producto, nombre_calidad, precio):
    """Crea la calidad o, si ya existe, actualiza su precio de referencia."""
    with get_cursor() as cur:
        cur.execute(
            "INSERT INTO calidad VALUES (%s,%s,%s) "
            "ON CONFLICT (cod_producto, nombre_calidad) DO UPDATE SET precio_referencia = EXCLUDED.precio_referencia",
            (cod_producto, nombre_calidad, precio))


def eliminar(tabla, columna, valor):
    """Da de baja un registro de catalogo (baja logica; la base no permite borrarlo fisicamente)."""
    baja_logica(tabla, valor)
