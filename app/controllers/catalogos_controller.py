"""CONTROLADOR: productores, clientes, productos y calidades."""
from app.controllers.utils import parse_decimal, requerido
from app.errors import AppError
from app.models import catalogos
from app.audit import registrar_evento

REGIONES = ["Ica", "Chincha", "Pisco", "Pedregal", "Tacna"]
UNIDADES = ["Kilogramo", "Caja"]


def productores():
    return catalogos.listar_productores()


def nuevo_productor(nombre, region):
    if region not in REGIONES:
        raise AppError("Selecciona una región válida.")
    nombre = requerido(nombre, "Nombre")
    codigo = catalogos.crear_productor(nombre, region)
    registrar_evento("INSERTAR", "productor", codigo, {"nombre": nombre, "region": region})
    return codigo


def eliminar_productor(id_):
    catalogos.eliminar("productor", "id_productor", id_)
    registrar_evento("ELIMINAR", "productor", id_)


def clientes():
    return catalogos.listar_clientes()


def nuevo_cliente(nombre, domicilio, telefono):
    nombre = requerido(nombre, "Nombre")
    domicilio = domicilio.strip() or None; telefono = telefono.strip() or None
    codigo = catalogos.crear_cliente(nombre, domicilio, telefono)
    registrar_evento("INSERTAR", "cliente", codigo, {"nombre": nombre, "domicilio": domicilio, "telefono": telefono})
    return codigo


def eliminar_cliente(id_):
    catalogos.eliminar("cliente", "id_cliente", id_)
    registrar_evento("ELIMINAR", "cliente", id_)


def productos():
    return catalogos.listar_productos()


def nuevo_producto(nombre, unidad, kg_por_caja):
    if unidad not in UNIDADES:
        raise AppError("Selecciona la unidad de medida.")
    nombre = requerido(nombre, "Nombre"); kg = parse_decimal(kg_por_caja, "Kg por caja")
    codigo = catalogos.crear_producto(nombre, unidad, kg)
    registrar_evento("INSERTAR", "producto", codigo, {"nombre": nombre, "unidad": unidad, "kg_por_caja": kg})
    return codigo


def calidades(cod_producto=None):
    return catalogos.listar_calidades(cod_producto)


def guardar_calidad(cod_producto, nombre, precio):
    if not cod_producto:
        raise AppError("Selecciona un producto.")
    nombre = requerido(nombre, "Calidad"); precio_val = parse_decimal(precio, "Precio")
    catalogos.guardar_calidad(cod_producto, nombre, precio_val)
    registrar_evento("GUARDAR", "calidad/precio", f"{cod_producto}/{nombre}", {"precio": precio_val})
