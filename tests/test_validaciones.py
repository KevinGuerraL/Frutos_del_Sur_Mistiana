"""Pruebas aisladas de validaciones, sin acceso a PostgreSQL."""
import unittest
from decimal import Decimal

from app.errors import AppError
from app.controllers.utils import parse_decimal, parse_fecha, requerido
# Evita importar el modelo PostgreSQL: estas pruebas son de validación aislada.
import sys, types
sys.modules.setdefault("app.models.pedidos", types.ModuleType("app.models.pedidos"))
from app.controllers.pedido_controller import armar_linea


class ValidacionesTest(unittest.TestCase):
    def test_decimal_coma(self):
        self.assertEqual(parse_decimal("12,50", "Precio"), Decimal("12.50"))

    def test_decimal_rechaza_cero(self):
        with self.assertRaises(AppError):
            parse_decimal("0", "Cantidad")

    def test_decimal_rechaza_nan(self):
        with self.assertRaises(AppError):
            parse_decimal("NaN", "Cantidad")

    def test_decimal_rechaza_infinito(self):
        with self.assertRaises(AppError):
            parse_decimal("Infinity", "Cantidad")

    def test_decimal_rechaza_texto(self):
        with self.assertRaises(AppError):
            parse_decimal("abc", "Cantidad")

    def test_fecha_iso(self):
        self.assertEqual(str(parse_fecha("2026-11-20")), "2026-11-20")

    def test_fecha_peruana(self):
        self.assertEqual(str(parse_fecha("20/11/2026")), "2026-11-20")

    def test_fecha_invalida(self):
        with self.assertRaises(AppError):
            parse_fecha("31/02/2026")

    def test_requerido(self):
        with self.assertRaises(AppError):
            requerido("  ", "Nombre")

    def test_cajas_entero(self):
        with self.assertRaises(AppError):
            armar_linea("PA01", "Primera", "Cajas", "1.5", "10", [])

    def test_unidad_invalida(self):
        with self.assertRaises(AppError):
            armar_linea("PA01", "Primera", "Litros", "1", "10", [])

    def test_linea_duplicada(self):
        existing = [{"cod_producto":"PA01", "nombre_calidad":"Primera"}]
        with self.assertRaises(AppError):
            armar_linea("PA01", "Primera", "Kilos", "1", "10", existing)


if __name__ == "__main__":
    unittest.main()
