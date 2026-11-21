"""Validaciones comunes de los controladores."""
from datetime import date, datetime
from decimal import Decimal, InvalidOperation

from app.errors import AppError


def parse_fecha(texto):
    texto = (texto or "").strip()
    for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y"):
        try:
            return datetime.strptime(texto, fmt).date()
        except ValueError:
            pass
    raise AppError("Fecha inválida. Usa AAAA-MM-DD o DD/MM/AAAA.")


def parse_decimal(texto, campo, positivo=True):
    try:
        valor = Decimal((texto or "").strip().replace(",", "."))
    except InvalidOperation:
        raise AppError(f"'{campo}' debe ser un número.")
    if not valor.is_finite():
        raise AppError(f"'{campo}' debe ser un número válido.")
    if positivo and valor <= 0:
        raise AppError(f"'{campo}' debe ser mayor que 0.")
    return valor


def requerido(texto, campo):
    texto = (texto or "").strip()
    if not texto:
        raise AppError(f"El campo '{campo}' es obligatorio.")
    return texto


def hoy():
    return date.today().isoformat()
