"""CONTROLADOR: stock, cierre del dia (Tarea 4) y consultas."""
from decimal import Decimal

from app.controllers.utils import parse_fecha
from app.models import reportes


def stock():
    return reportes.stock()


def cierre(fecha_txt):
    """Devuelve (resumen, notas) del dia indicado."""
    fecha = parse_fecha(fecha_txt)
    notas = reportes.cierre_notas(fecha)
    contado = sum((n["total"] for n in notas if n["modalidad_pago"] == "Contado"), Decimal(0))
    credito = sum((n["total"] for n in notas if n["modalidad_pago"] == "Crédito"), Decimal(0))
    resumen = {"notas": len(notas), "ventas_totales": contado + credito,
               "a_transferir_contado": contado, "pendiente_credito": credito,
               "compras_del_dia": reportes.cierre_compras(fecha)}
    return resumen, notas


def consultas():
    return reportes.cargar_consultas()


def ejecutar(sql):
    return reportes.ejecutar(sql)
