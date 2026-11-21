"""CONTROLADOR: Tarea 3 - Asignacion y reparto a clientes (notas de pedido)."""
from pathlib import Path

from app.controllers.utils import parse_decimal, parse_fecha
from app.errors import AppError
from app.models import pedidos
from app.audit import registrar_evento

MODALIDADES = ["Contado", "Crédito"]


def hojas():
    return pedidos.hojas_disponibles()


def stock_texto(cod_producto, nombre_calidad):
    if not cod_producto or not nombre_calidad:
        return ""
    s = pedidos.stock_de(cod_producto, nombre_calidad)
    return f"Stock disponible: {s['stock']} {s['unidad_medida'].lower()}(s)" if s else ""


def armar_linea(cod_producto, nombre_calidad, unidad, cantidad_txt, precio_txt, existentes):
    """unidad: 'Cajas' o 'Kilos'."""
    if not cod_producto or not nombre_calidad:
        raise AppError("Selecciona producto y calidad.")
    if any(l["cod_producto"] == cod_producto and l["nombre_calidad"] == nombre_calidad for l in existentes):
        raise AppError("Esa calidad ya está en la nota. Quítala y vuelve a agregarla si deseas cambiarla.")
    precio = parse_decimal(precio_txt, "Precio unitario")
    if unidad not in ("Cajas", "Kilos"):
        raise AppError("Selecciona si la cantidad se registra en cajas o kilos.")
    if unidad == "Cajas":
        cant = parse_decimal(cantidad_txt, "Cajas")
        if cant != int(cant):
            raise AppError("Las cajas deben ser un número entero.")
        return {"cod_producto": cod_producto, "nombre_calidad": nombre_calidad,
                "cajas": int(cant), "kilos": None, "precio_unitario": precio}
    return {"cod_producto": cod_producto, "nombre_calidad": nombre_calidad,
            "cajas": None, "kilos": parse_decimal(cantidad_txt, "Kilos"), "precio_unitario": precio}


def leer_firma(ruta):
    if not ruta:
        return None
    return Path(ruta).read_bytes()


def registrar(fecha_txt, modalidad, id_compra, id_cliente, lineas, firma=None):
    fecha = parse_fecha(fecha_txt)
    if modalidad not in MODALIDADES:
        raise AppError("Selecciona la modalidad de pago.")
    if not id_compra:
        raise AppError("Selecciona la hoja de control de compra de la que se abastece.")
    if not id_cliente:
        raise AppError("Selecciona el cliente.")
    if not lineas:
        raise AppError("Agrega al menos una línea a la nota de pedido.")
    numero = pedidos.crear(fecha, modalidad, id_compra, id_cliente, lineas, firma)
    registrar_evento("INSERTAR", "pedido", numero, {"fecha": fecha, "modalidad": modalidad, "hoja_compra": id_compra, "cliente": id_cliente, "lineas": lineas, "firma_adjunta": bool(firma)})
    return numero


def listar():
    return pedidos.listar()


def detalle(numero):
    return pedidos.detalle(numero)


def eliminar(numero):
    pedidos.eliminar(numero)
    registrar_evento("ELIMINAR", "pedido", numero)
