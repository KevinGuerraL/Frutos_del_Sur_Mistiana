"""CONTROLADOR: Tarea 2 - Monitoreo de stock (hojas de control de compra)."""
from app.controllers.utils import parse_decimal
from app.errors import AppError
from app.models import compras
from app.audit import registrar_evento


def retiros_pendientes():
    return compras.retiros_pendientes()


def generar_hoja(id_retiro):
    if not id_retiro:
        raise AppError("Selecciona un retiro pendiente.")
    codigo = compras.generar_hoja(id_retiro)
    registrar_evento("INSERTAR", "hoja_control_compra", codigo, {"retiro": id_retiro})
    return codigo


def hojas():
    return compras.listar_hojas()


def detalle(id_compra):
    return compras.detalle_hoja(id_compra)


def cambiar_precio(id_compra, cod_producto, nombre_calidad, precio_txt):
    precio = parse_decimal(precio_txt, "Precio")
    compras.actualizar_precio(id_compra, cod_producto, nombre_calidad, precio)
    registrar_evento("MODIFICAR", "precio_compra", f"{id_compra}/{cod_producto}/{nombre_calidad}", {"precio_nuevo": precio})
