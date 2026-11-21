"""CONTROLADOR: Tarea 1 - Registro de retiro."""
from app.controllers.utils import parse_decimal, parse_fecha
from app.errors import AppError
from app.models import retiros
from app.audit import registrar_evento


def listar():
    return retiros.listar()


def detalle(id_retiro):
    return retiros.detalle(id_retiro)


def registrar(fecha_txt, id_productor, lineas):
    """lineas: lista de dicts con cod_producto, nombre_calidad, cantidad (ya Decimal)."""
    fecha = parse_fecha(fecha_txt)
    if not id_productor:
        raise AppError("Selecciona el productor.")
    if not lineas:
        raise AppError("Agrega al menos una línea (producto, calidad y cantidad).")
    codigo = retiros.crear(fecha, id_productor, lineas)
    registrar_evento("INSERTAR", "retiro", codigo, {"fecha": fecha, "productor": id_productor, "lineas": lineas})
    return codigo


def armar_linea(cod_producto, nombre_calidad, cantidad_txt, existentes):
    if not cod_producto or not nombre_calidad:
        raise AppError("Selecciona producto y calidad.")
    if any(l["cod_producto"] == cod_producto and l["nombre_calidad"] == nombre_calidad for l in existentes):
        raise AppError("Esa calidad ya fue agregada en este retiro.")
    return {"cod_producto": cod_producto, "nombre_calidad": nombre_calidad,
            "cantidad": parse_decimal(cantidad_txt, "Cantidad")}


def eliminar(id_retiro):
    retiros.eliminar(id_retiro)
    registrar_evento("ELIMINAR", "retiro", id_retiro)
